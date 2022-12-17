#
# Manifeste de module pour le module « Wsl-Manager »
#
# Généré par : Antoine Martin
#
# Généré le : 05/05/2022
#

@{

    # Module de script ou fichier de module binaire associé à ce manifeste
    RootModule        = 'Wsl-Manager.psm1'

    # Numéro de version de ce module.
    ModuleVersion     = '1.0.0'

    # Éditions PS prises en charge
    # CompatiblePSEditions = @()

    # ID utilisé pour identifier de manière unique ce module
    GUID              = 'bc998dd2-0e00-42cf-a564-4d9f99a1d044'

    # Auteur de ce module
    Author            = 'Antoine Martin'

    # Société ou fournisseur de ce module
    CompanyName       = 'Openance'

    # Déclaration de copyright pour ce module
    Copyright         = '(c) 2022 Antoine Martin. Tous droits réservés.'

    # Description de la fonctionnalité fournie par ce module
    Description       = 'Powershell cmdlet to quickly create a small Arch Linux based WSL distribution'

    # Version minimale du moteur Windows PowerShell requise par ce module
    # PowerShellVersion = ''

    # Nom de l'hôte Windows PowerShell requis par ce module
    # PowerShellHostName = ''

    # Version minimale de l'hôte Windows PowerShell requise par ce module
    # PowerShellHostVersion = '6.0'

    # Version minimale du Microsoft .NET Framework requise par ce module. Cette configuration requise est valide uniquement pour PowerShell Desktop Edition.
    # DotNetFrameworkVersion = ''

    # Version minimale de l’environnement CLR (Common Language Runtime) requise par ce module. Cette configuration requise est valide uniquement pour PowerShell Desktop Edition.
    # CLRVersion = ''

    # Architecture de processeur (None, X86, Amd64) requise par ce module
    # ProcessorArchitecture = ''

    # Modules qui doivent être importés dans l'environnement global préalablement à l'importation de ce module
    # RequiredModules = @()

    # Assemblys qui doivent être chargés préalablement à l'importation de ce module
    # RequiredAssemblies = @()

    # Fichiers de script (.ps1) exécutés dans l’environnement de l’appelant préalablement à l’importation de ce module
    # ScriptsToProcess = @()

    # Fichiers de types (.ps1xml) à charger lors de l'importation de ce module
    # TypesToProcess = @()

    # Fichiers de format (.ps1xml) à charger lors de l'importation de ce module
    # FormatsToProcess = @()

    # Modules à importer en tant que modules imbriqués du module spécifié dans RootModule/ModuleToProcess
    NestedModules     = @('Wsl-RootFS.psm1')

    # Fonctions à exporter à partir de ce module. Pour de meilleures performances, n’utilisez pas de caractères génériques et ne supprimez pas l’entrée. Utilisez un tableau vide si vous n’avez aucune fonction à exporter.
    FunctionsToExport = @("Install-Wsl", "Uninstall-Wsl", "Export-Wsl", "Get-WslRootFS", "Get-Wsl", "Invoke-Wsl")

    # Applets de commande à exporter à partir de ce module. Pour de meilleures performances, n’utilisez pas de caractères génériques et ne supprimez pas l’entrée. Utilisez un tableau vide si vous n’avez aucune applet de commande à exporter.
    CmdletsToExport   = @()

    # Variables à exporter à partir de ce module
    VariablesToExport = '*'

    # Alias à exporter à partir de ce module. Pour de meilleures performances, n’utilisez pas de caractères génériques et ne supprimez pas l’entrée. Utilisez un tableau vide si vous n’avez aucun alias à exporter.
    AliasesToExport   = @()

    # Ressources DSC à exporter depuis ce module
    # DscResourcesToExport = @()

    # Liste de tous les modules empaquetés avec ce module
    # ModuleList = @()

    # Liste de tous les fichiers empaquetés avec ce module
    FileList          = @("p10k.zsh", "configure_arch.sh", "configure_alpine.sh", "configure_ubuntu.sh")

    # Données privées à transmettre au module spécifié dans RootModule/ModuleToProcess. Cela peut également inclure une table de hachage PSData avec des métadonnées de modules supplémentaires utilisées par PowerShell.
    PrivateData       = @{

        PSData = @{

            # Des balises ont été appliquées à ce module. Elles facilitent la découverte des modules dans les galeries en ligne.
            Tags       = @("WSL", "Windows", "Subsystem", "Linux", "Arch", "Alpine", "Ubuntu")

            # URL vers la licence de ce module.
            LicenseUri = 'https://github.com/antoinemartin/PowerShell-Wsl-Manager/blob/main/LICENSE'

            # URL vers le site web principal de ce projet.
            ProjectUri = 'https://github.com/antoinemartin/PowerShell-Wsl-Manager'

            # URL vers une icône représentant ce module.
            # IconUri = ''

            # Propriété ReleaseNotes de ce module
            # ReleaseNotes = ''

        } # Fin de la table de hachage PSData

    } # Fin de la table de hachage PrivateData

    # URI HelpInfo de ce module
    HelpInfoURI       = 'https://github.com/antoinemartin/PowerShell-Wsl-Manager/blob/main/README.md'

    # Le préfixe par défaut des commandes a été exporté à partir de ce module. Remplacez le préfixe par défaut à l’aide d’Import-Module -Prefix.
    # DefaultCommandPrefix = ''

}

