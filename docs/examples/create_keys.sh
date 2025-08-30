#!/bin/zsh
# cSpell: ignore mainkey subkey subkeys

# Default values
KEY_TYPE="rsa4096"
EXPIRE_MAIN="0"
EXPIRE_SUB="1y"

# Usage function
usage() {
    echo "Usage: $0 [-t key_type] <email> <name>"
    echo "  -t key_type  Key type (default: rsa4096)"
    echo "  email        Email address for the key"
    echo "  name         Name for the key"
    exit 1
}

# Parse options
while getopts "t:h" opt; do
    case $opt in
        t)
            KEY_TYPE="$OPTARG"
            ;;
        h)
            usage
            ;;
        \?)
            echo "Invalid option: -$OPTARG" >&2
            usage
            ;;
    esac
done

# Shift past the options
shift $((OPTIND-1))

# Check if we have the required parameters
if [ $# -ne 2 ]; then
    echo "Error: Email and name are required parameters"
    usage
fi

KEY_EMAIL="$1"
KEY_NAME="$2"

# Generate main key (never expires)
gpg --batch --quick-generate-key \
    "${KEY_NAME} <${KEY_EMAIL}>" \
    "${KEY_TYPE}" \
    cert \
    "${EXPIRE_MAIN}"

# Get the fingerprint of the newly created key
MAINKEY_FPR=$(gpg --list-keys --with-colons "${KEY_EMAIL}" | awk -F: '/^fpr:/ {print $10; exit}')

# Add subkey: RSA 4096 Signing, expires in one year
gpg --batch --quick-add-key "${MAINKEY_FPR}" "${KEY_TYPE}" sign "${EXPIRE_SUB}"

# Add subkey: RSA 4096 Encryption, expires in one year
gpg --batch --quick-add-key "${MAINKEY_FPR}" "${KEY_TYPE}" encrypt "${EXPIRE_SUB}"

# Add subkey: RSA 4096 Authentication, expires in one year
gpg --batch --quick-add-key "${MAINKEY_FPR}" "${KEY_TYPE}" auth "${EXPIRE_SUB}"

echo "Done. Main key never expires. Subkeys expire in 1 year."
