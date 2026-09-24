param(
    [Parameter(Mandatory = $true)]
    [ValidatePattern('^1\.0\.\d+$')]
    [string]$Version,

    [Parameter(Mandatory = $true)]
    [ValidatePattern('^[0-9a-f]{40}$')]
    [string]$Commit
)

$ErrorActionPreference = 'Stop'
$tag = "v$Version"
$projectRoot = Split-Path -Parent $PSScriptRoot
$assets = @(
    (Join-Path $projectRoot "dist/helheim-$Version.jar"),
    (Join-Path $projectRoot "dist/helheim-$Version.zip")
)
foreach ($asset in $assets) {
    if (-not (Test-Path -LiteralPath $asset -PathType Leaf)) { throw "Missing release asset: $asset" }
}
if (-not $env:GH_REPO) { throw 'GH_REPO must identify the GitHub repository.' }

# Exit code 2 means no matching tag; other failures must not be treated as absence.
$tagRefs = @(& git -C $projectRoot ls-remote --exit-code --tags origin "refs/tags/$tag" "refs/tags/$tag^{}")
$tagExitCode = $LASTEXITCODE
if ($tagExitCode -notin @(0, 2)) { throw 'Failed to query remote tags.' }
$tagExists = $tagExitCode -eq 0
if ($tagExists) {
    # Resolve annotated tags to their commit as well as supporting lightweight tags.
    $tagCommit = & gh api "repos/$env:GH_REPO/commits/$tag" --jq '.sha'
    if ($LASTEXITCODE -ne 0) { throw 'Failed to resolve the existing tag.' }
    if ($tagCommit -ne $Commit) { throw "Tag $tag already points to another commit." }
}

# Paginate so reruns also find old releases; API errors stop publication.
$releaseId = & gh api "repos/$env:GH_REPO/releases" --paginate --jq ".[] | select(.tag_name == `"$tag`") | .id"
if ($LASTEXITCODE -ne 0) { throw 'Failed to query existing releases.' }
if ($releaseId) {
    if (-not $tagExists) { throw "Release $tag exists but its tag is missing." }
    & gh release upload $tag @assets --clobber
    if ($LASTEXITCODE -ne 0) { throw 'Failed to replace release assets.' }
}
else {
    $releaseArgs = @(
        'release', 'create', $tag
    ) + $assets + @(
        '--target', $Commit, '--generate-notes', '--title', "Helheim $tag", '--latest=false'
    )
    & gh @releaseArgs
    if ($LASTEXITCODE -ne 0) { throw 'Failed to publish the release.' }
}
