# Debug (`dbg`)

Debugging on steroids for Minetest mods

## Motivation

Lua offers very powerful introspective facilities through its `debug` library, which unfortunately almost always go unused due to their clunky APIs.

Current state-of-the-art in Minetest mod debugging appears to be print/log/chat "debugging" using serialization or `dump`,
all of which should be rendered obsolete by `dbg`.

## API

**Optionally depend on `dbg` in `mod.conf` to ensure that it is available for load-time debugging.**

### `dbg()`

Shorter alias for `dbg.dd()`.

`debug.debug()` on steroids: Starts a REPL (read-eval-print-loop); equivalent to a breakpoint. Features include:

* Full access to locals & upvalues of the calling function
* Own local table `_L` where `local` debug vars get stored
* Ability to enter expressions (rather than statements)
* Continuation, which works the same as in the Lua REPL (+ empty lines working)
* Pretty-printing using `dbg.pp`, including syntax highlighting

Enter `cont` to exit without an error. Use `err` to throw after error debugging sessions (`dbg.error`, `dbg.assert`).

Use EOF (<kbd>Ctrl + D</kbd> on Unix) to exit & shut down Minetest.

### `dbg.error(message, [level])`

Starts a debugging session at the given (optional) level, printing the error message.

### `dbg.assert(value, [message])`

Returns `value`. Starts an error debugging session if `value` is falsey. Error `message` is optional.

### `dbg.pp(...)`

Pretty-prints the given vararg using the default parameters.

If the argument list of functions is unreliable (see `dbg.getargs_reliable` below),
a question mark (`?`) will be appended to the argument list to indicate this.

### `dbg.ppp(params, ...)`

Parameterized pretty-print. Requires a custom pretty-printer parameter table `params`:

* `write = function(str, token_type)`, where `token_type` is optional and may be one of `nil`, `boolean`, `number`, `string`, `reference`, `function` or `type`
* `upvalues = true`, whether upvalues should be written

### `dbg.vars(level)`

Returns a virtual variable table of locals & upvalues `vars` for the given stacklevel that supports the following operations:

* Getting: `vars.varname`
* Setting: `vars.varname = value`
* Looping: `for varname, value in vars() do ... end`

### `dbg.locals(level)`

Returns a virtual variable table of local values at the given stack level.

Locals include upvalues.

### `dbg.upvals(func)`

`func` may be either a function or a stack level (including `nil`, which defaults to the stack level of the calling function).

Returns a virtual variable table of upvalues at the given stack level.

### `dbg.traceback(level)`

Formats a stack trace starting at `level`. Similar to Lua's builtin `debug.stacktrace`, but shortens paths and accepts no `message` to prepend.

### `dbg.stackinfo(level)`

Returns a list of `info` by repeatedly calling `debug.getinfo` starting with `level` and working down the stack.

### `dbg.getvararg(level)`

**Only available on LuaJIT; on PUC Lua 5.1, `dbg.getvararg` will be `nil`.**

Returns the vararg at the given stack level.

### `dbg.getargs(func)`

**Function parameter list detection doesn't work properly on PUC Lua 5.1; unused params are lost and varargs are turned into `arg`.**
Use `dbg.getargs_reliable` (boolean) to check for reliability.

Returns a table containing the argument names of `func` in string form
(example: `{"x", "y", "z", "..."}` for `function(x, y, z, ...) end`).

### `dbg.shorten_path(path)`

Shortens `path`: If path is a subpath of a mod, it will be shortened to `"<modname>:<subpath>"`.

## Security

Debug deliberately exposes the unrestricted `debug` API globally, as well as the `dbg` wrapper API,
both of which can be abused to exit the mod security sandbox.

**Only use `dbg` in environments where you trust all enabled mods.**
**Adding `dbg` to `secure.trusted_mods` (recommended) or disabling mod security (not recommended) is required.**

The `/lua` chatcommand must explicitly be enabled on servers by setting `secure.dbg.lua` to `true`;
if enabled, server owners risk unprivileged users gaining access through MITM attacks.

## Usage

**Prerequisites:** LuaJIT and a terminal with decent ANSI support are highly recommended.

### `/dbg`

Calls `dbg()` to start debugging in the console.

### `/lua <code>`

Executes the code and pretty-prints the result(s) to chat.
Only available in singleplayer for security reasons (risk of MITM attacks).

---

Links: [GitHub](https://github.com/appgurueu/dbg), [ContentDB](https://content.minetest.net/packages/LMD/dbg), [Minetest Forums](https://forum.minetest.net/viewtopic.php?f=9&t=28372)

License: Written by Lars Müller and licensed under the MIT license (see `License.txt`).
