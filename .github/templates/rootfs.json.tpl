{
"Type": "Builtin",
"Name": "{{ .Env.FLAVOR }}{{ .Env.WSL_SUFFIX }}",
"Os": "{{ .Env.FLAVOR | strings.Title }}",
"Distribution": "{{ .Env.FLAVOR | strings.Title }}",
"Url": "docker://{{ .Env.REGISTRY }}/{{ .Env.IMAGE_NAME }}{{ .Env.WSL_SUFFIX }}#latest",
"Hash": {
    "Type": "docker"
},
"Digest": "{{ .Env.WSL_DIGEST }}",
"Release": "{{ .Env.VERSION }}",
"Configured": {{ .Env.WSL_CONFIGURED }},
"Username": "{{ .Env.WSL_USERNAME }}",
"Uid": {{ .Env.WSL_UID }},
"LocalFilename": "{{ .Env.WSL_DIGEST }}.rootfs.tar.gz",
"Size": {{ .Env.WSL_SIZE }},
"Tags": ["{{ .Env.WSL_TAGS }}"]
}
