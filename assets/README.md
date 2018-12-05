# Install compiler
```
# pacman -S opam
$ opam switch create 4.02.3+buckle-1
$ eval $(opam env)
$ # echo prefix=~/.npm > ~/.npmrc
$ npm install -g bs-platform
$ opam install reason
```

# Configure vscode
Replace `$HOME` to your home folder.
```json
{
  "reason.path.bsb": "$HOME/.npm/bin/bsb",
  "reason.path.env": "/usr/bin/env",
  "reason.path.esy": "$HOME/.opam/4.02.3+buckle-1/bin/esy",
  "reason.path.ocamlfind": "$HOME/.opam/4.02.3+buckle-1/bin/ocamlfind",
  "reason.path.ocamlmerlin": "$HOME/.opam/4.02.3+buckle-1/bin/ocamlmerlin",
  "reason.path.ocpindent": "$HOME/.opam/4.02.3+buckle-1/bin/ocp-indent",
  "reason.path.opam": "/usr/bin/opam",
  "reason.path.rebuild": "$HOME/.opam/4.02.3+buckle-1/bin/rebuild",
  "reason.path.refmt": "$HOME/.opam/4.02.3+buckle-1/bin/refmt",
  "reason.path.refmterr": "$HOME/.opam/4.02.3+buckle-1/bin/refmterr",
  "reason.path.rtop": "$HOME/.opam/4.02.3+buckle-1/bin/rtop"
}
```

# Build
```
$ opam switch 4.02.3+buckle-1
$ eval $(opam env)
$ yarn build
```

# Watch

```
npm run watch
```


# Editor
If you use `vscode`, Press `Windows + Shift + B` it will build automatically