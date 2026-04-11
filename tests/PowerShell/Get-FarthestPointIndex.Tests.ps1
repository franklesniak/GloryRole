BeforeAll {
    # Avoid relative-path segments per style guide checklist item
    $strSrcPath = Join-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -ChildPath 'src'
    . (Join-Path -Path $strSrcPath -ChildPath 'Get-SquaredEuclideanDistance.ps1')
    . (Join-Path -Path $strSrcPath -ChildPath 'Get-FarthestPointIndex.ps1')
}

Describe "Get-FarthestPointIndex" {
    Context "When finding the farthest point from a single centroid" {
        It "Returns the index of the farthest point" {
            # Arrange
            $arrVectorRows = @(
                [pscustomobject]@{ Vector = [double[]]@(0.0, 0.0) }
                [pscustomobject]@{ Vector = [double[]]@(1.0, 0.0) }
                [pscustomobject]@{ Vector = [double[]]@(10.0, 0.0) }
            )
            $listCentroids = New-Object 'System.Collections.Generic.List[double[]]'
            $listCentroids.Add([double[]]@(0.0, 0.0))

            # Act
            $intResult = Get-FarthestPointIndex -VectorRows $arrVectorRows -Centroids $listCentroids

            # Assert
            $intResult | Should -Be 2
        }
    }

    Context "When using multiple centroids" {
        It "Returns the index with the greatest nearest-centroid distance" {
            # Arrange
            $arrVectorRows = @(
                [pscustomobject]@{ Vector = [double[]]@(5.0, 0.0) }
                [pscustomobject]@{ Vector = [double[]]@(0.0, 3.0) }
                [pscustomobject]@{ Vector = [double[]]@(2.5, 2.5) }
            )
            $listCentroids = New-Object 'System.Collections.Generic.List[double[]]'
            $listCentroids.Add([double[]]@(0.0, 0.0))
            $listCentroids.Add([double[]]@(5.0, 0.0))

            # Act
            $intResult = Get-FarthestPointIndex -VectorRows $arrVectorRows -Centroids $listCentroids

            # Assert
            # Index 0 nearest-centroid dist = 0.0 (on centroid (5,0))
            # Index 1 nearest-centroid dist = 9.0 (nearest is (0,0))
            # Index 2 nearest-centroid dist = 12.5 (equidistant from both)
            $intResult | Should -Be 2
        }
    }

    Context "When given a single vector row" {
        It "Returns index 0" {
            # Arrange
            $arrVectorRows = @(
                [pscustomobject]@{ Vector = [double[]]@(3.0, 4.0) }
            )
            $listCentroids = New-Object 'System.Collections.Generic.List[double[]]'
            $listCentroids.Add([double[]]@(0.0, 0.0))

            # Act
            $intResult = Get-FarthestPointIndex -VectorRows $arrVectorRows -Centroids $listCentroids

            # Assert
            $intResult | Should -Be 0
        }
    }

    Context "When all points are equidistant" {
        It "Returns index 0 as the first encountered index" {
            # Arrange
            $arrVectorRows = @(
                [pscustomobject]@{ Vector = [double[]]@(1.0, 0.0) }
                [pscustomobject]@{ Vector = [double[]]@(0.0, 1.0) }
                [pscustomobject]@{ Vector = [double[]]@(-1.0, 0.0) }
            )
            $listCentroids = New-Object 'System.Collections.Generic.List[double[]]'
            $listCentroids.Add([double[]]@(0.0, 0.0))

            # Act
            $intResult = Get-FarthestPointIndex -VectorRows $arrVectorRows -Centroids $listCentroids

            # Assert
            # All points are at squared distance 1.0 from the centroid;
            # the > comparison means the first index (0) wins.
            $intResult | Should -Be 0
        }
    }

    Context "When the farthest point is at the last index" {
        It "Returns the last index" {
            # Arrange
            $arrVectorRows = @(
                [pscustomobject]@{ Vector = [double[]]@(0.0, 0.0) }
                [pscustomobject]@{ Vector = [double[]]@(1.0, 0.0) }
                [pscustomobject]@{ Vector = [double[]]@(2.0, 0.0) }
                [pscustomobject]@{ Vector = [double[]]@(100.0, 0.0) }
            )
            $listCentroids = New-Object 'System.Collections.Generic.List[double[]]'
            $listCentroids.Add([double[]]@(0.0, 0.0))

            # Act
            $intResult = Get-FarthestPointIndex -VectorRows $arrVectorRows -Centroids $listCentroids

            # Assert
            $intResult | Should -Be 3
        }
    }

    Context "When using higher-dimensional vectors" {
        It "Returns the correct farthest point index for 4D vectors" {
            # Arrange
            $arrVectorRows = @(
                [pscustomobject]@{ Vector = [double[]]@(0.0, 0.0, 0.0, 0.0) }
                [pscustomobject]@{ Vector = [double[]]@(1.0, 1.0, 1.0, 1.0) }
                [pscustomobject]@{ Vector = [double[]]@(5.0, 5.0, 5.0, 5.0) }
            )
            $listCentroids = New-Object 'System.Collections.Generic.List[double[]]'
            $listCentroids.Add([double[]]@(0.0, 0.0, 0.0, 0.0))

            # Act
            $intResult = Get-FarthestPointIndex -VectorRows $arrVectorRows -Centroids $listCentroids

            # Assert
            # Index 2 is at squared distance 100.0 (5^2 * 4 dimensions)
            $intResult | Should -Be 2
        }
    }

    Context "When given invalid input" {
        It "Throws an error when vector rows lack a Vector property" {
            # Arrange
            $arrVectorRows = @(
                [pscustomobject]@{ Name = 'invalid' }
            )
            $listCentroids = New-Object 'System.Collections.Generic.List[double[]]'
            $listCentroids.Add([double[]]@(1.0, 2.0))

            # Act & Assert
            { Get-FarthestPointIndex -VectorRows $arrVectorRows -Centroids $listCentroids } | Should -Throw
        }
    }
}
