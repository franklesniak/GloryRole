"""Tests for the example module.

This test file demonstrates:
- Basic pytest test structure
- Testing functions with different input scenarios
- Testing error conditions with pytest.raises

This is a TEMPLATE FILE. Replace these tests with your actual test cases
when using this template repository.
"""

import pytest

from copilot_repo_template.example import add_numbers, greet


class TestGreet:
    """Tests for the greet function."""

    def test_greet_returns_greeting(self) -> None:
        """Test that greet returns a proper greeting message."""
        result = greet("World")
        assert result == "Hello, World!"

    def test_greet_with_different_name(self) -> None:
        """Test greet with a different name."""
        result = greet("Copilot")
        assert result == "Hello, Copilot!"

    def test_greet_raises_on_empty_string(self) -> None:
        """Test that greet raises ValueError for empty string."""
        with pytest.raises(ValueError, match="cannot be empty or whitespace"):
            greet("")

    def test_greet_raises_on_whitespace(self) -> None:
        """Test that greet raises ValueError for whitespace-only string."""
        with pytest.raises(ValueError, match="cannot be empty or whitespace"):
            greet("   ")


class TestAddNumbers:
    """Tests for the add_numbers function."""

    def test_add_integers(self) -> None:
        """Test adding two integers."""
        result = add_numbers(2, 3)
        assert result == 5

    def test_add_floats(self) -> None:
        """Test adding two floats."""
        result = add_numbers(2.5, 3.5)
        assert result == 6.0

    def test_add_mixed_types(self) -> None:
        """Test adding an integer and a float."""
        result = add_numbers(2, 3.5)
        assert result == 5.5

    def test_add_negative_numbers(self) -> None:
        """Test adding negative numbers."""
        result = add_numbers(-5, 3)
        assert result == -2
