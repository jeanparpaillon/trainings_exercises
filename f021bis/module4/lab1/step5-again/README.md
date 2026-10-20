# Step 5 — run it all again, compare

**Slides:** *Lab 1* (Observe) · **~5 min**

The test of a task is its **second** run.

```sh
./bootstrap.sh       # root's password again
./adhoc.sh
```

Read the colour of each result: **green** `ok` — the state was already
there, nothing done; **yellow** `changed` — something was done.

Now add two commands to the end of `adhoc.sh`, and run it again, twice:

```sh
ansible all -m ansible.builtin.command -a 'uptime'
ansible all -m ansible.builtin.shell -a 'ss -tlnp | grep :22'
```

## Check

- every command of steps 2 and 4: `ok` on the second run;
- `command` and `shell`: `changed`, every time.

Lab 1's end state:

```sh
ansible all -m ansible.builtin.ping          # green, no option
git add -A && git commit -m "lab 1" && git tag lab1
git log --oneline && git tag
```

## Questions

- Why are `command` and `shell` always `changed`? What would they need to
  know to report `ok`? (Session 2 comes back to `creates:` and
  `changed_when:`.)
- Try the second one with `ansible.builtin.command` instead of `shell`.
  What does it print, and why?
- Change the motd text in `adhoc.sh` and run the copy again: `changed`.
  Then run it with `--check --diff` before running it for real. What does
  each option do?
