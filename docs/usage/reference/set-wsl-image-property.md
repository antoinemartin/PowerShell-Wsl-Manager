# Set-WslImageProperty

```text

NAME
    Set-WslImageProperty

SYNOPSIS
    Sets a property of a WSL image.


SYNTAX
    Set-WslImageProperty [-ImageName] <String> -PropertyName <String> [-Value <Object>] [-Source <WslImageSource>] [-Force] [-WhatIf] [-Confirm] [<CommonParameters>]

    Set-WslImageProperty -Image <WslImage> -PropertyName <String> [-Value <Object>] [-Source <WslImageSource>] [-Force] [-WhatIf] [-Confirm] [<CommonParameters>]


DESCRIPTION
    The Set-WslImageProperty cmdlet changes the value of a specified property on a
    WSL image. The image is identified either by its name or by passing a WslImage
    object.

    Standard properties that can be changed without -Force:
    - Name
    - Distribution
    - Release
    - Username
    - Uid
    - Configured

    Advanced properties requiring -Force:
    - Type
    - SourceId
    - Url
    - LocalFilename
    - DigestUrl
    - DigestAlgorithm
    - DigestType
    - FileHash
    - State


PARAMETERS
    -ImageName <String>
        The name of the image to modify. Use this parameter when specifying the image
        by name.

    -Image <WslImage>
        The WslImage object to modify. Can be piped to this cmdlet.

    -PropertyName <String>
        The name of the property to change.

    -Value <Object>
        The new value for the property.

    -Source <WslImageSource>
        A WslImageSource object. When specified with PropertyName 'SourceId', the SourceId
        of the image will be set to the Id of this source.

    -Force [<SwitchParameter>]
        Required when changing advanced properties (Type, SourceId, Url, etc.).

    -WhatIf [<SwitchParameter>]

    -Confirm [<SwitchParameter>]

    <CommonParameters>
        This cmdlet supports the common parameters: Verbose, Debug,
        ErrorAction, ErrorVariable, WarningAction, WarningVariable,
        OutBuffer, PipelineVariable, and OutVariable. For more information, see
        about_CommonParameters (https://go.microsoft.com/fwlink/?LinkID=113216).

    -------------------------- EXAMPLE 1 --------------------------

    PS > Set-WslImageProperty -ImageName "MyImage" -PropertyName "Name" -Value "NewName"
    Changes the name of the image "MyImage" to "NewName".






    -------------------------- EXAMPLE 2 --------------------------

    PS > Set-WslImageProperty -ImageName "MyImage" -PropertyName "Distribution" -Value "Ubuntu"
    Changes the distribution of "MyImage" to "Ubuntu".






    -------------------------- EXAMPLE 3 --------------------------

    PS > $image = Get-WslImage -Name "MyImage"
    $source = Get-WslImageSource -Name "alpine"
    Set-WslImageProperty -Image $image -PropertyName "SourceId" -Source $source -Force
    Changes the source of the image to the alpine image source.






    -------------------------- EXAMPLE 4 --------------------------

    PS > Get-WslImage -Name "MyImage" | Set-WslImageProperty -PropertyName "State" -Value "NotDownloaded" -Force
    Changes the state of "MyImage" to NotDownloaded using pipeline input.






REMARKS
    To see the examples, type: "Get-Help Set-WslImageProperty -Examples"
    For more information, type: "Get-Help Set-WslImageProperty -Detailed"
    For technical information, type: "Get-Help Set-WslImageProperty -Full"
    For online help, type: "Get-Help Set-WslImageProperty -Online"


```
