## Intent

The intent of this change is to provide a cmdlet allowing to change the
properties of a WSL image, such as its name, distribution, release, default
user, and UID.

This is the equivalent of the following code:

```powershell
$wslImage = Get-WslImage -Name "MyImage"
$wslImage.Name = "NewName"
$db = [WslImageDatabase]::GetDatabase()
$db = InModuleScope -ModuleName Wsl-Manager {
    Get-WslImageDatabase  # This cmdlet is internal, so we need to use InModuleScope
}
$db.SaveLocalImage($wslImage.ToObject())
```

## Specification

The name of the property to change is specified using the `-Name` parameter, and
the new value using the `-Value` parameter.

The properties that can be changed are:

- Name
- Distribution
- Release
- DefaultUser
- DefaultUid
- Configured

As a convenience, the cmdlet allows to change the other properties of the image
as long as the `-Force` switch is specified.

Those properties are:

- Type
- SourceId
- Url
- LocalFilename
- DigestUrl
- DigestAlgorithm
- DigestType
- FileHash

The SourceId can be changed in two ways:

- By specifying a new SourceId directly. In this case, it is the caller's
  responsibility to ensure that the specified SourceId corresponds to an
  existing Source (hence the `-Force` switch). The cmdlet will try to fetch the
  Source with the specified Id, and will throw an error if it does not exist.
- By specifying a new Source (using the `-Source` parameter), in which case the
  SourceId is updated to match the Id of the specified Source. In case the `Id`
  property of the specified Source is null or empty, an error is thrown.

The cmdlet exposes the common parameters `-WhatIf`, `-Confirm`, `-Verbose`...

The image to modify is specified in two ways:

- By specifying its name using the `-ImageName` parameter.
- By specifying the image object itself using the `-Image` parameter. This is
  the Pipeline input.

### Examples

```powershell
Set-WslImageProperty -ImageName "MyImage" -Name "Name" -Value "NewName"
Set-WslImageProperty -ImageName "MyImage" -Name "Distribution" -Value "Ubuntu"
$image = Get-WslImage -Name "MyImage"
$ImageSource = Get-WslImageSource -Name "alpine"
Set-WslImageProperty -Image $image -Name "SourceId" -Source $ImageSource -Force
Get-WslImage -Name "MyImage" | Set-WslImageProperty -Name "State" -Value "NotDownloaded" -Force
```

## Implementation

The cmdlet should be implemented in the file `Wsl-Image/Wsl-Image.Cmdlets.ps1`,
in a region named `Set-WslImageProperty`. The cmdlet should be named
`Set-WslImageProperty`.

The cmdlet should first retrieve the image to modify, either from the `-Image`
parameter or from the `-ImageName` parameter. they should be in different
parameter sets.

Then, the cmdlet should check the value of the `-Name` parameter, and update the
corresponding property of the image object with the value specified in the
`-Value` parameter.

The cmdlet should be exported in the module manifest file `Wsl-Manager.psd1`.
the alias `swslip` should be created for the cmdlet.

The cmdlet should support `-WhatIf` and `-Confirm` common parameters.

The documentation for the cmdlet should be added as a comment-based help in the
cmdlet implementation. Then, the documentation file in the
`docs/usage/reference` directory should be created by running the following
command:

```powershell
pwsh -File "./hack/Invoke-ReferenceDocumentationBuild.ps1" -ModuleName "Wsl-Manager" -DestinationDirectory "./docs/usage/reference"
```

## Tests

Unit tests should be added to cover the new cmdlet in the file
`Wsl-Image.Tests.ps1`. For the tests, a context named `SetWslImageProperty`
should be created.

All the tests can be invoked using the following command:

```powershell
pwsh ./hack/Invoke-Tests.ps1 Filter 'WslImage.SetWslImageProperty.*'
```

The basic test should create a WSL image from a local tarball created with
`New-MockImage`, and progressively change its properties using the cmdlet in
order to match the values of a builtin image (for example, `alpine-base`). Look
at existing tests in `Wsl-Image.Tests.ps1` for examples of how to create mock
images and use the cmdlets. At each step, the test should verify that the
property has been correctly updated by re-fetching the image with
`Get-WslImage`.

The tests should offer 100% code coverage for the cmdlet.

## Pre-commit Checks

Before submitting the code, ensure that all pre-commit checks are passing by
adding the modified files to the staging area and running the following command:

```powershell
pre-commit run
```
