#!/usr/bin/env node

/**
 * Lint Nested Markdown Script
 *
 * This script extracts Markdown code blocks from Markdown files and runs
 * markdownlint on them to ensure nested Markdown content follows the same
 * linting rules as the outer Markdown files.
 *
 * Usage:
 *   Scan all files:   node .github/scripts/lint-nested-markdown.js
 *   Lint specific files:  node .github/scripts/lint-nested-markdown.js file1.md file2.md
 *
 * When file arguments are provided, only those files are linted (useful for pre-commit hooks).
 * When no arguments are provided, all .md files are scanned via glob (excluding node_modules).
 * Both absolute and relative paths are supported; relative paths are resolved from cwd.
 */

const fs = require('fs');
const path = require('path');
const { glob } = require('glob');
const MarkdownIt = require('markdown-it');
const { lint } = require('markdownlint/promise');
const jsoncParser = require('jsonc-parser');

// Initialize markdown-it parser
const md = new MarkdownIt();

// Repository root is two levels up from this script's location in .github/scripts/
const REPO_ROOT = path.resolve(__dirname, '../..');

// ANSI color codes for terminal output
const colors = {
    reset: '\x1b[0m',
    red: '\x1b[31m',
    yellow: '\x1b[33m',
    green: '\x1b[32m',
    cyan: '\x1b[36m',
    bold: '\x1b[1m'
};

/**
 * Resolve file paths from command-line arguments to absolute paths
 * @param {string[]} args - Command-line arguments (file paths)
 * @returns {Object} Object with validFiles array and skippedFiles array
 */
function resolveFilePaths(args) {
    const validFiles = [];
    const skippedFiles = [];

    for (const arg of args) {
        // Resolve relative paths from current working directory
        const absolutePath = path.isAbsolute(arg)
            ? arg
            : path.resolve(process.cwd(), arg);

        if (fs.existsSync(absolutePath)) {
            validFiles.push(absolutePath);
        } else {
            skippedFiles.push(arg);
        }
    }

    return { validFiles, skippedFiles };
}

/**
 * Load markdownlint configuration from .markdownlint.jsonc or .markdownlint.json
 */
function loadMarkdownlintConfig() {
    const configPaths = [
        path.join(REPO_ROOT, '.markdownlint.jsonc'),
        path.join(REPO_ROOT, '.markdownlint.json')
    ];

    for (const configPath of configPaths) {
        if (fs.existsSync(configPath)) {
            try {
                const content = fs.readFileSync(configPath, 'utf8');
                // Use jsonc-parser for proper JSONC handling (supports comments in strings)
                return jsoncParser.parse(content);
            } catch (error) {
                console.warn(`Warning: Could not read config file ${configPath}: ${error.message}`);
                continue;
            }
        }
    }
    return {};
}

/**
 * Extract markdown code fences from content (recursive)
 * @param {string} content - Markdown content to parse
 * @param {string} filePath - Path to the original markdown file
 * @param {number} baseLine - Line number offset in the original file
 * @param {number} depth - Current nesting depth
 * @param {string} parentPath - Path description for nested blocks
 * @returns {Array} Array of extracted blocks with metadata
 */
function extractMarkdownFencesRecursive(content, filePath, baseLine = 0, depth = 0, parentPath = '') {
    const tokens = md.parse(content, {});
    const blocks = [];

    for (let i = 0; i < tokens.length; i++) {
        const token = tokens[i];

        // Look for fence tokens with markdown language identifier
        if (token.type === 'fence' &&
            (token.info.trim().toLowerCase() === 'markdown' ||
             token.info.trim().toLowerCase() === 'md')) {

            const blockLine = baseLine + (token.map ? token.map[0] + 1 : 0);
            const blockPath = parentPath ? `${parentPath} > block at line ${blockLine}` : `line ${blockLine}`;

            const blockInfo = {
                content: token.content,
                line: blockLine,
                info: token.info.trim(),
                filePath: filePath,
                depth: depth,
                parentPath: blockPath
            };

            blocks.push(blockInfo);

            // Recursively extract nested markdown fences
            if (token.content.trim().length > 0) {
                const nestedBlocks = extractMarkdownFencesRecursive(
                    token.content,
                    filePath,
                    blockLine,
                    depth + 1,
                    blockPath
                );
                blocks.push(...nestedBlocks);
            }
        }
    }

    return blocks;
}

/**
 * Extract markdown code fences from a file
 * @param {string} filePath - Path to the markdown file
 * @returns {Array} Array of extracted blocks with metadata
 */
function extractMarkdownFences(filePath) {
    let content;
    try {
        content = fs.readFileSync(filePath, 'utf8');
    } catch (error) {
        console.error(`Error reading file ${filePath}: ${error.message}`);
        return [];
    }
    return extractMarkdownFencesRecursive(content, filePath, 0, 0, '');
}

/**
 * Run markdownlint on extracted content
 * @param {string} content - Markdown content to lint
 * @param {object} config - Markdownlint configuration
 * @returns {Promise<object>} Markdownlint results
 */
async function lintMarkdownContent(content, config) {
    // Create a modified config for nested markdown
    // Disable MD041 (first-line-heading) since nested markdown snippets
    // may not start with a top-level heading
    // Disable MD051 (link-fragments) since nested markdown often contains
    // example/placeholder links that reference anchors in other documents
    const nestedConfig = {
        ...config,
        'MD041': false,
        'MD051': false
    };

    const options = {
        strings: {
            'content': content
        },
        config: nestedConfig
    };

    return await lint(options);
}

/**
 * Format and display linting results
 * @param {Array} allResults - Array of results with context
 * @returns {boolean} True if any errors were found
 */
function displayResults(allResults) {
    let hasErrors = false;

    if (allResults.length === 0) {
        console.log(`${colors.green}✓${colors.reset} No issues found in nested Markdown code fences`);
        return false;
    }

    console.log(`\n${colors.bold}${colors.red}Nested Markdown Linting Issues:${colors.reset}\n`);

    for (const result of allResults) {
        if (result.errors.length === 0) {
            continue;
        }

        hasErrors = true;

        console.log(`${colors.cyan}File:${colors.reset} ${result.filePath}`);
        const depthIndicator = result.depth > 0 ? ` ${colors.yellow}[depth ${result.depth}]${colors.reset}` : '';
        const pathInfo = result.parentPath ? ` (${result.parentPath})` : '';
        console.log(`  ${colors.yellow}Code fence at line ${result.line}${depthIndicator} (${result.info} block #${result.blockIndex})${pathInfo}:${colors.reset}`);

        for (const error of result.errors) {
            // Calculate the actual line number in the outer file
            // result.line is the fence opening line (e.g., line 9)
            // error.lineNumber is 1-based line within the content (e.g., line 1 is first content line)
            // Content starts at result.line + 1, so line N of content is at result.line + N
            const actualLineNumber = result.line + error.lineNumber;
            const nestedLineInfo = result.depth > 0 ? ` (nested line ${error.lineNumber})` : '';
            console.log(`    ${actualLineNumber}:${error.errorRange ? error.errorRange[0] : 1}${nestedLineInfo} ${colors.red}${error.ruleNames.join('/')}${colors.reset} ${error.ruleDescription}`);
            if (error.errorDetail) {
                console.log(`      ${colors.yellow}${error.errorDetail}${colors.reset}`);
            }
        }

        console.log('');
    }

    return hasErrors;
}

/**
 * Main function
 */
async function main() {
    try {
        console.log(`${colors.bold}Linting nested Markdown in code fences...${colors.reset}\n`);

        // Load markdownlint configuration
        const config = loadMarkdownlintConfig();

        // Check for command-line file arguments
        const cliArgs = process.argv.slice(2);
        let files;

        if (cliArgs.length > 0) {
            // Use files provided as arguments
            const { validFiles, skippedFiles } = resolveFilePaths(cliArgs);

            // Warn about skipped files
            for (const skipped of skippedFiles) {
                console.warn(`${colors.yellow}Warning: File not found, skipping: ${skipped}${colors.reset}`);
            }

            files = validFiles;
            console.log(`Linting ${files.length} specified file(s)\n`);
        } else {
            // Find all markdown files (excluding node_modules)
            files = await glob('**/*.md', {
                ignore: ['node_modules/**', '**/node_modules/**'],
                cwd: REPO_ROOT,
                absolute: true
            });
            console.log(`Found ${files.length} Markdown file(s) to scan\n`);
        }

        let totalBlocks = 0;
        const allResults = [];

        // Process each file
        for (const file of files) {
            const relativePath = path.relative(REPO_ROOT, file);
            const blocks = extractMarkdownFences(file);

            if (blocks.length > 0) {
                console.log(`${colors.cyan}${relativePath}${colors.reset}: Found ${blocks.length} nested Markdown block(s)`);
                totalBlocks += blocks.length;

                // Lint each extracted block
                for (let index = 0; index < blocks.length; index++) {
                    const block = blocks[index];

                    // Skip empty blocks
                    if (!block.content || block.content.trim().length === 0) {
                        continue;
                    }

                    const lintResults = await lintMarkdownContent(block.content, config);
                    const errors = lintResults.content || [];

                    if (errors.length > 0) {
                        allResults.push({
                            filePath: relativePath,
                            line: block.line,
                            info: block.info,
                            blockIndex: index + 1,
                            depth: block.depth,
                            parentPath: block.parentPath,
                            errors: errors
                        });
                    }
                }
            }
        }

        console.log(`\nTotal nested Markdown blocks found: ${totalBlocks}\n`);

        // Display results
        const hasErrors = displayResults(allResults);

        if (hasErrors) {
            console.log(`${colors.red}${colors.bold}✗${colors.reset} ${colors.red}Nested Markdown linting failed${colors.reset}\n`);
            process.exit(1);
        } else {
            console.log(`${colors.green}${colors.bold}✓${colors.reset} ${colors.green}Nested Markdown linting passed${colors.reset}\n`);
            process.exit(0);
        }

    } catch (error) {
        console.error(`${colors.red}Error:${colors.reset}`, error.message);
        console.error(error.stack);
        process.exit(1);
    }
}

// Run main function
main();
