# lore

Felix's roles for coding agents: a [rolesmith](https://github.com/sunfmin/rolesmith) library.

```sh
rolesmith source add felix https://github.com/sunfmin/lore
rolesmith list
rolesmith use ios-app-coder --into claude-code
```

`rolesmith check` validates it. Roles came from Guild's lore (sunfminforge/lore), which Guild still reads in its own layout.

On a factorium host, each promotion of `main` is cut by `cut/install-roles`: it updates this library's rolesmith source and moves every worker role directory (`~/.local/share/roles/*`) to the new `main`, and each git project that follows lore (a committed `.rolesmith-follow` naming its branch, as control's does) in a commit of rolesmith's own files pushed to that branch, one JSON line per project; `cut/test_install_roles.py`, in the gate, tests it on a fixture host.
