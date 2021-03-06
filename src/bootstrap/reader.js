
var primitives = require('bootstrap/primitives');
var S = primitives.S,
    K = primitives.K,
    HashSymbol = primitives.HashSymbol;

function Reader (stream) {
    this.stream = stream;
}
exports.Reader = Reader;

Reader.prototype.read = function () {
    this.stream.skipWhitespace();
    if (!this.stream.eof()) {
        switch (this.stream.peekChar()) {
        case ';':
            this.stream.skipLine();
            return this.read();
        case '"':
            return this.readString();
        case '(':
            return this.readList(')');
        case '[':
            return [S('js:array')]
                .concat(this.readList(']'));
        case '`':
            this.stream.readChar();
            return [S('%backquote'),
                    this.read()];
        case ',':
            this.stream.readChar();
            return [S('%comma'),
                    this.read()];
        default:
            return this.readAtom();
        }
    }
};

var hexNumberExpression = /^[+-]?0x[0-9a-f]+/i;
var octalNumberExpression = /^[+-]?0[0-7]+/;
var decimalNumberExpression = /^[+-]?\d+\.?\d*(?:e-?\d*(?:\d\.?|\.?\d)\d*)?/i;

Reader.prototype.readAtom = function () {
    var c = this.stream.peekChar();
    var rest = this.stream.rest();
    if ([hexNumberExpression,
         octalNumberExpression,
         decimalNumberExpression]
        .some(function (expression) {
            var match = expression.exec(rest);
            return match && match[0] != '';
        }))
    {
        return this.readNumber();
    } else
        return this.readSymbol();
};

Reader.prototype.readList = function (end) {
    var result = new Array();
    this.stream.readChar();
    this.stream.skipWhitespace();

    while (this.stream.peekChar() != end) {
        if (this.stream.eof())
            throw new Error('Unbalanced parens');
        if (this.stream.peekChar() == ';')
            this.stream.skipLine();
        else {
            var next = this.read();
            result.push(next);
        }
        this.stream.skipWhitespace();
    }

    this.stream.readChar();
    return result;
};

Reader.prototype.readSymbol = function () {
    var match = /[^()\[\]\n\r\t ]+/.exec(this.stream.rest());
    var name = match[0];
    var rest = name.substring(1);
    this.stream.index += name.length;
    if (name == "#t") {
	    return true;
    } else if (name == "#f") {
	    return false;
    } else if (name[0] == '#' &&
               (HashSymbol.names.indexOf(rest) >= 0))
    {
	    return HashSymbol[rest];
    } else if (name[name.length - 1] == ":") {
	    return K(name.slice(0, -1).toLowerCase());
    } else
	    return S(name.toLowerCase());
};

Reader.prototype.readString = function () {
    this.stream.readChar();
    var c, result = "";
    while ((c = this.stream.readChar()) != '"') {
	if (c == '\\')
	  result += '\\' + this.stream.readChar();
	else if (c == '\n')
	    result += '\\n\\\n';
	else
	    result += c;
    }
    return result;
};

Reader.prototype.readNumber = function () {
    var match = /[^\[\]()\n\r\t ]+/.exec(this.stream.rest());
    this.stream.index += match[0].length;
    return new Number(match[0]);
};