# New-WslImageHash

```text

NAME
    New-WslImageHash

SYNOPSIS
    Creates a new FileSystem hash holder.


SYNTAX
    New-WslImageHash [-Url] <String> [[-Algorithm] <String>] [[-Type] <String>] [<CommonParameters>]


DESCRIPTION
    The WslImageHash object holds checksum information for one or more
    distributions in order to check it upon download and determine if the filesystem
    has been updated.

    Note that the checksums are not downloaded until the `Retrieve()` method has been
    called on the object.


PARAMETERS
    -Url <String>
        The Url where the checksums are located.

        Required?                    true
        Position?                    1
        Default value
        Accept pipeline input?       false
        Aliases
        Accept wildcard characters?  false

    -Algorithm <String>
        The checksum algorithm. Nowadays, we find mostly SHA256.

        Required?                    false
        Position?                    2
        Default value                SHA256
        Accept pipeline input?       false
        Aliases
        Accept wildcard characters?  false

    -Type <String>
        Type can either be `sums` in which case the file contains one
        <checksum> <filename> pair per line, or `single` and just contains the hash for
        the file which name is the last segment of the Url minus the extension. For
        instance, if the URL is `https://.../rootfs.tar.xz.sha256`, we assume that the
        checksum it contains is for the file named `rootfs.tar.xz`.

        Required?                    false
        Position?                    3
        Default value                sums
        Accept pipeline input?       false
        Aliases
        Accept wildcard characters?  false

    <CommonParameters>
        This cmdlet supports the common parameters: Verbose, Debug,
        ErrorAction, ErrorVariable, WarningAction, WarningVariable,
        OutBuffer, PipelineVariable, and OutVariable. For more information, see
        about_CommonParameters (https://go.microsoft.com/fwlink/?LinkID=113216).

INPUTS

OUTPUTS

NOTES


        General notes

    -------------------------- EXAMPLE 1 --------------------------

    PS > New-WslImageHash https://cloud-images.ubuntu.com/wsl/noble/current/SHA256SUMS
    Creates the hash source for several files with SHA256 (default) algorithm.






    -------------------------- EXAMPLE 2 --------------------------

    PS > New-WslImageHash https://.../rootfs.tar.xz.sha256 -Type `single`
    Creates the hash source for the rootfs.tar.xz file with SHA256 (default) algorithm.







RELATED LINKS



```
