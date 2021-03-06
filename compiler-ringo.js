var Server = require('ringo/httpserver').Server;
var core, stream, reader, compiler, optimization;

function parseParameters (input) {
    var params = {};
    input.split("&").forEach(function (keyValue) {
        var splitted = keyValue.split('=');
        var name = splitted[0];
        var value = splitted[1] == "true";
        params[name.trim()] = value;
    });
    return params;
}

function app (request) {
	// TODO: ugly workaround caused by 0.8 API change
    var req = request.env.servletRequest;
    var inputStream = req.getInputStream();
    var code = "", chunk;
    while (chunk = inputStream.read(), chunk >= 0)
        code += String.fromCharCode(chunk);
	var query = req.getQueryString();
    var options = parseParameters(query);

    try {
        var sourceStream =
            core.make(stream._CL_stringStream, core._k("string"),
                      "(begin\n" + code + "\n)");
        sourceStream.line = 1;
        var form = reader.read(sourceStream);
        var compiled = compiler.compile(form,
                                        core._k('statements?'), ((options && options.hasOwnProperty('statements'))
                                                                 ? !!options.statements : true),
                                        core._k('asynchronous?'), options && !!options.asynchronous);
        if (!!options.optimize)
            compiled = optimization.optimize(compiled,
                                             core._k('pretty-print?'), !!options.pretty,
                                             core._k('minimize?'), !!options.minimize);
        return { status: 200,
                 headers: {'Content-Type': 'text/javascript'},
                 body: [compiled]
               };

    } catch (e) {
        return { status: 500,
                 headers: {},
                 body: [e.stack.toString()] };
    }

}

var server = new Server({app: app, port: 5000});

core = require("ralph/core"),
stream = require("ralph/stream"),
reader = require("ralph/reader"),
compiler = require("ralph/compiler"),
optimization = require("ralph/optimization");

server.start();
