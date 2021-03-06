# Install compiler
```
# pacman -S opam base-devel
$ # opam init
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
  "reason.path.rtop": "$HOME/.opam/4.02.3+buckle-1/bin/rtop",
  "npm.packageManager": "yarn"
}
```

# Development Note
```
$ yarn add reason-react
$ yarn add --dev rollup rollup-plugin-commonjs rollup-plugin-node-resolve
$ yarn add --dev rollup-plugin-alias rollup-plugin-replace rollup-plugin-bucklescript rollup-plugin-copy-glob
$ yarn add bootstrap jquery popper.js

# pacman -S php php-tidy
```

# Build
```
$ opam switch 4.02.3+buckle-1
$ eval $(opam env)
$ yarn build # start
$ yarn rollup
```

# Deploy
```
ln -s ../../../../assets _build/prod/rel/jx3app/
```
