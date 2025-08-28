{
"Type": "Builtin",
"Name": "{{ .Env.FLAVOR }}{{ .Env.WSL_SUFFIX }}",
"Os": "{{ .Env.FLAVOR | strings.Title }}",
"Url": "docker://{{ .Env.REGISTRY }}/{{ .Env.IMAGE_NAME }}{{ .Env.WSL_SUFFIX }}#latest",
"Hash": {
    "Type": "docker"
},
"Release": "{{ .Env.VERSION }}",
"Configured": {{ .Env.WSL_CONFIGURED }},
"Username": "{{ .Env.WSL_USERNAME }}",
"Uid": {{ .Env.WSL_UID }},
"LocalFilename": "docker.{{ .Env.FLAVOR }}{{ .Env.WSL_SUFFIX }}.rootfs.tar.gz"
}
