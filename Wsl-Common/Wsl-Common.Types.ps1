class WslManagerException : System.SystemException {
    WslManagerException([string] $message) : base($message) {
    }
    WslManagerException([string] $message, [System.Exception] $innerException) : base($message, $innerException ) {
    }
}

class UnknownWslInstanceException : WslManagerException {
    UnknownWslInstanceException([string] $Name) : base("Unknown instance(s): $Name") {
    }
}

class WslImageException : WslManagerException {
    WslImageException([string] $message) : base($message) {
    }
    WslImageException([string] $message, [System.Exception] $innerException) : base($message, $innerException ) {
    }
}

class UnknownWslImageException : WslManagerException {
    UnknownWslImageException([string] $Name) : base("Unknown image(s): $Name") {
    }
}

class WslInstanceAlreadyExistsException : WslManagerException {
    WslInstanceAlreadyExistsException([string] $Name) : base("WSL instance $Name already exists") {
    }
}

class WslImageAlreadyExistsException : WslManagerException {
    WslImageAlreadyExistsException([string] $Name) : base("WSL image $Name already exists") {
    }
}

class WslImageDownloadException : WslImageException {
    WslImageDownloadException([string] $message) : base($message) {
    }
    WslImageDownloadException([string] $message, [System.Exception] $innerException) : base($message, $innerException ) {
    }
}
