"""Interpret a small, strict Pawn subset for source regression fixtures.

This is a test double, not an AMXX compiler/VM or an HLDS simulator. Unsupported
syntax fails instead of silently inventing language/engine behavior. Functions
are read from installed includes; engine and graph natives are supplied by tests.
"""
import ast
import operator
import re

from test_mapper_contracts import body


def split_top(text, separator=','):
    parts, start, depth, quoted = [], 0, 0, None
    for i, char in enumerate(text):
        if char in "\"'" and (i == 0 or text[i-1] not in '^\\'):
            quoted = None if quoted == char else char if quoted is None else quoted
        if quoted:
            continue
        depth += (char in '([')-(char in ')]')
        if char == separator and not depth:
            parts.append(text[start:i].strip())
            start = i+1
    return parts+[text[start:].strip()]


class Flow(Exception):
    def __init__(self, kind, value=0):
        self.kind, self.value = kind, value


class Ref:
    def __init__(self, get, put):
        self.get, self.put = get, put


class VectorView:
    """Pawn enum vector fields are contiguous views, not copied list slices."""
    def __init__(self, values, span):
        self.values, self.indices = values, list(range(*span.indices(len(values))))

    def __len__(self):
        return len(self.indices)

    def __getitem__(self, index):
        if isinstance(index, slice):
            return [self.values[i] for i in self.indices[index]]
        return self.values[self.indices[index]]

    def __setitem__(self, index, value):
        if isinstance(index, slice):
            indices = self.indices[index]
            assert len(indices) == len(value), 'Pawn vectors cannot resize'
            for i, item in zip(indices, value):
                self.values[i] = item
        else:
            self.values[self.indices[index]] = value


class Parser:
    def __init__(self, text):
        self.text = re.sub(r'//[^\n]*|/\*[\s\S]*?\*/', '', text)
        self.index = 0

    def skip(self):
        while self.index < len(self.text) and self.text[self.index].isspace():
            self.index += 1

    def keyword(self, word):
        self.skip()
        if re.match(re.escape(word)+r'\b', self.text[self.index:]):
            self.index += len(word)
            return True
        return False

    def group(self):
        self.skip()
        assert self.text[self.index] == '('
        start = self.index+1
        self.index += 1
        depth = 1
        while depth:
            depth += (self.text[self.index] == '(')-(self.text[self.index] == ')')
            self.index += 1
        return self.text[start:self.index-1]

    def block(self):
        items = []
        while True:
            self.skip()
            if self.index == len(self.text) or self.text[self.index] == '}':
                return ('block', items)
            items.append(self.statement())

    def statement(self):
        self.skip()
        if self.text[self.index] == '{':
            self.index += 1
            result = self.block()
            self.index += 1
            return result
        if self.keyword('if'):
            condition, yes = self.group(), self.statement()
            no = self.statement() if self.keyword('else') else ('block', [])
            return ('if', condition, yes, no)
        if self.keyword('for'):
            parts = split_top(self.group(), ';')
            assert len(parts) == 3
            return ('for', *parts, self.statement())
        if self.keyword('while'):
            return ('while', self.group(), self.statement())
        if self.keyword('switch'):
            value = self.group()
            self.skip()
            assert self.text[self.index] == '{'
            self.index += 1
            cases = {}
            while True:
                self.skip()
                if self.text[self.index] == '}':
                    self.index += 1
                    return ('switch', value, cases)
                assert self.keyword('case'), 'Only explicit cases supported'
                colon = self.text.index(':', self.index)
                label = self.text[self.index:colon].strip()
                self.index = colon+1
                cases[label] = self.statement()
        start, depth, quoted = self.index, 0, False
        while self.index < len(self.text):
            char = self.text[self.index]
            if char == '"':
                quoted = not quoted
            if not quoted:
                depth += (char in '([')-(char in ')]')
                if char == '\n' and not depth and self.text[self.index+1:].lstrip().startswith(('&&', '||')):
                    self.index += 1
                    continue
                if char in ';\n}' and not depth:
                    break
            self.index += 1
        text = self.text[start:self.index].strip()
        if self.index < len(self.text) and self.text[self.index] in ';\n':
            self.index += 1
        assert text, 'Empty/unsupported statement'
        return ('line', text)


class Scope:
    def __init__(self, global_values, local_values):
        self.global_values, self.local_values = global_values, local_values

    def ref(self, name):
        if name.startswith('__pawn_'):
            name = name[7:]
        values = self.local_values if name in self.local_values else self.global_values
        if name not in values:
            raise AssertionError('Undeclared fixture value: '+name)
        if isinstance(values[name], Ref):
            return values[name]
        return Ref(lambda: values[name], lambda value: values.__setitem__(name, value))


class PawnRuntime:
    def __init__(self, values):
        self.values, self.functions, self.steps = values, {}, 0

    def bind(self, name, function, references=()):
        self.functions[name] = (function, set(references))

    def load(self, source, names):
        for name in names:
            declaration = re.search(r'\b(?:stock|public)\s+(?:\w+:)?'+name+r'\s*\(([^)]*)\)', source)
            parameters = split_top(declaration[1]) if declaration[1].strip() else []
            labels = [re.search(r'(?:const\s+)?&?(?:\w+:)?(\w+)', p)[1] for p in parameters]
            references = [i for i, p in enumerate(parameters) if '&' in p]
            defaults = [p.split('=', 1)[1].strip() if '=' in p else None for p in parameters]
            tree = Parser(body(source, name)).block()

            def call(*args, labels=labels, defaults=defaults, tree=tree):
                assert len(args) <= len(labels), (labels, args)
                args = list(args)
                for default in defaults[len(args):]:
                    assert default is not None, (labels, args)
                    args.append(self.value(default, Scope(self.values, {})))
                scope = Scope(self.values, dict(zip(labels, args)))
                try:
                    self.execute(tree, scope)
                except Flow as flow:
                    assert flow.kind == 'return'
                    return flow.value
                return 0

            self.bind(name, call, references)

    def call(self, name, *args):
        return self.functions[name][0](*args)

    def expression(self, text):
        text = re.sub(r'\b(?:bool|Float|_)\s*:', '', text.strip()).replace('\n', ' ').replace('\t', ' ')
        text = re.sub(r'\bfrom\b', '__pawn_from', text)
        text = text.replace('>>>', '>>')  # All fixture handles are positive 31-bit cells.
        text = re.sub(r'\btrue\b', 'True', text)
        text = re.sub(r'\bfalse\b', 'False', text)
        text = text.replace('&&', ' and ').replace('||', ' or ')
        text = re.sub(r'!(?!=)', ' not ', text)
        variable = r'[A-Za-z_]\w*(?:\[[^\[\]]+\])*'
        text = re.sub(r'(\+\+|--)('+variable+r')', lambda m: '__inc('+repr(m[2])+','+('1' if m[1] == '++' else '-1')+',False)', text)
        text = re.sub(r'('+variable+r')(\+\+|--)', lambda m: '__inc('+repr(m[1])+','+('1' if m[2] == '++' else '-1')+',True)', text)
        text = re.sub(r'\bsizeof\s+('+variable+r')', r'__sizeof(\1)', text)
        index, rebuilt = 0, ''
        while index < len(text):
            if text[index] != '(':
                rebuilt += text[index]
                index += 1
                continue
            start, nesting = index+1, 1
            index += 1
            while nesting:
                nesting += (text[index] == '(')-(text[index] == ')')
                index += 1
            inner = text[start:index-1]
            rebuilt += '('+','.join(self.expression(part) for part in split_top(inner))+')'
        text = rebuilt
        depth = 0
        for i, char in enumerate(text):
            depth += (char in '([')-(char in ')]')
            if char == '?' and not depth:
                colon = text.index(':', i)
                return '('+self.expression(text[i+1:colon])+' if '+self.expression(text[:i])+' else '+self.expression(text[colon+1:])+')'
        return text.strip()

    def reference(self, node, scope):
        if isinstance(node, ast.Name):
            return scope.ref(node.id)
        assert isinstance(node, ast.Subscript), ast.dump(node)
        values, index = self.evaluate(node.value, scope), self.evaluate(node.slice, scope)
        return Ref(lambda: VectorView(values, index) if isinstance(index, slice) else values[index],
                   lambda value: values.__setitem__(index, value))

    def evaluate(self, node, scope):
        if isinstance(node, ast.Constant):
            return node.value
        if isinstance(node, (ast.Name, ast.Subscript)):
            return self.reference(node, scope).get()
        if isinstance(node, ast.IfExp):
            return self.evaluate(node.body if self.evaluate(node.test, scope) else node.orelse, scope)
        if isinstance(node, ast.UnaryOp):
            return {ast.Not: operator.not_, ast.USub: operator.neg, ast.Invert: operator.invert}[type(node.op)](self.evaluate(node.operand, scope))
        if isinstance(node, ast.BoolOp):
            if isinstance(node.op, ast.And):
                return all(self.evaluate(v, scope) for v in node.values)
            return any(self.evaluate(v, scope) for v in node.values)
        if isinstance(node, ast.Compare):
            left = self.evaluate(node.left, scope)
            for op, right in zip(node.ops, node.comparators):
                right = self.evaluate(right, scope)
                if not {ast.Eq: operator.eq, ast.NotEq: operator.ne, ast.Lt: operator.lt, ast.LtE: operator.le,
                        ast.Gt: operator.gt, ast.GtE: operator.ge}[type(op)](left, right):
                    return False
                left = right
            return True
        if isinstance(node, ast.BinOp):
            left, right = self.evaluate(node.left, scope), self.evaluate(node.right, scope)
            if isinstance(node.op, ast.Div):
                return int(left/right) if isinstance(left, int) and isinstance(right, int) else left/right
            return {ast.Add: operator.add, ast.Sub: operator.sub, ast.Mult: operator.mul, ast.Mod: operator.mod,
                    ast.BitAnd: operator.and_, ast.BitOr: operator.or_, ast.BitXor: operator.xor,
                    ast.LShift: operator.lshift, ast.RShift: operator.rshift}[type(node.op)](left, right)
        assert isinstance(node, ast.Call) and isinstance(node.func, ast.Name), ast.dump(node)
        name = node.func.id
        if name == '__inc':
            target = self.reference(ast.parse(self.evaluate(node.args[0], scope), mode='eval').body, scope)
            previous = target.get()
            target.put(previous+self.evaluate(node.args[1], scope))
            return previous if self.evaluate(node.args[2], scope) else target.get()
        if name == '__sizeof':
            return len(self.evaluate(node.args[0], scope))
        function, references = self.functions[name]
        return function(*(self.reference(value, scope) if i in references else self.evaluate(value, scope)
                          for i, value in enumerate(node.args)))

    def value(self, text, scope):
        return self.evaluate(ast.parse(self.expression(text), mode='eval').body, scope)

    def line(self, text, scope):
        if text.startswith('return'):
            raise Flow('return', self.value(text[6:], scope) if text[6:].strip() else 0)
        if text in ('break', 'continue'):
            raise Flow(text)
        if text.startswith('new '):
            for declaration in split_top(text[4:]):
                declaration = re.sub(r'^\w+:', '', declaration)
                parts = declaration.split('=', 1)
                match = re.fullmatch(r'(\w+)((?:\[[^]]+\])*)', parts[0].strip())
                assert match, declaration
                dimensions = [int(self.value(s, scope)) for s in re.findall(r'\[([^]]+)\]', match[2])]

                def array(ds):
                    return [array(ds[1:]) for _ in range(ds[0])] if ds else 0

                scope.local_values[match[1]] = self.value(parts[1], scope) if len(parts) == 2 else array(dimensions)
            return
        masked = re.sub(r'"(?:\^.|[^"\n])*"', lambda m: ' '*len(m[0]), text)
        matches = list(re.finditer(r'(?<![<>=!])([+\-*/&|]?=)(?!=)', masked))
        assignment = matches[0] if matches else None
        if assignment:
            parts, begin = [], 0
            for match in matches if assignment[1] == '=' else matches[:1]:
                assert match[1] == assignment[1], 'Mixed chained assignments unsupported'
                parts.append(text[begin:match.start()])
                begin = match.end()
            parts.append(text[begin:])
            value = self.value(parts[-1], scope)
            for left in reversed(parts[:-1]):
                target = self.reference(ast.parse(self.expression(left), mode='eval').body, scope)
                if assignment[1] != '=':
                    value = { '+=': operator.add, '-=': operator.sub, '*=': operator.mul,
                              '|=': operator.or_, '&=': operator.and_ }[assignment[1]](target.get(), value)
                target.put(value)
            return
        self.value(text, scope)

    def execute(self, statement, scope):
        self.steps += 1
        assert self.steps < 1000000, 'Fixture execution exceeded limit'
        kind = statement[0]
        if kind == 'block':
            for child in statement[1]:
                self.execute(child, scope)
        elif kind == 'line':
            self.line(statement[1], scope)
        elif kind == 'if':
            self.execute(statement[2] if self.value(statement[1], scope) else statement[3], scope)
        elif kind == 'switch':
            value = self.value(statement[1], scope)
            for label, child in statement[2].items():
                if value == self.value(label, scope):
                    self.execute(child, scope)
                    break
        elif kind in ('for', 'while'):
            if kind == 'for':
                if statement[1]:
                    self.line(statement[1], scope)
                condition, update, child = statement[2:]
            else:
                condition, child = statement[1:]
                update = ''
            while not condition or self.value(condition, scope):
                try:
                    self.execute(child, scope)
                except Flow as flow:
                    if flow.kind == 'break':
                        break
                    if flow.kind != 'continue':
                        raise
                if update:
                    self.line(update, scope)
        else:
            raise AssertionError(kind)
