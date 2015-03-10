{TextEditor} = require 'atom'

describe "Ledger grammar", ->
  [grammar] = []

  beforeEach ->
    grammarFile = path.join __dirname, '../grammars/ledger.json'
    grammar = atom.grammars.readGrammarSync grammarFile

  it "parses the grammar", ->
    expect(grammar).toBeTruthy()
    expect(grammar.scopeName).toBe 'source.ledger'

  describe "grammar", ->
    it "tokenizes directives", ->
      directiveLists =
        'keyword.account': ['account']
        'keyword.commodity': ['commodity']
        'keyword.directive': [
          'alias',
          'assert',
          'bucket',
          'capture',
          'check',
          'define',
          'include',
          'tag',
          'year', 'Y']

      for scope, list of directiveLists
        for directive in list
          {tokens} = grammar.tokenizeLine directive
          expect(tokens[0].value).toEqual directive
          expect(tokens[0].scopes).toEqual ['source.ledger', scope]

    it "tokenizes line comments", ->
      tokensByLines = grammar.tokenizeLines """
; This is a single line comment,
#  and this,
%   and this,
|    and this,
*     and this.
"""
      for tokens in tokensByLines
        expect(tokens[0].value).toMatch /[Tt]his/
        expect(tokens[0].scopes).toEqual ['source.ledger', 'comment.line']

    xit "tokenizes block directives and block comments", ->
      directiveLists =
        'directive.block': ['apply account', 'apply tag']
        'comment.block' : ['comment']

      for scope, list of directiveLists
        for directive in list
          tokensByLines = grammar.tokenizeLines """
#{directive}
  This is a block directive or block comment with
  multiple lines
end #{directive}
"""
          expect(tokensByLines[0][0].value).toEqual directive
          for tokens in tokensByLines
            expect(tokens[0].scopes).toEqual ['source.ledger', scope]

    it "tokenizes accounts declared by account directive", ->
      {tokens} = grammar.tokenizeLine('account equity')
      expect(tokens[2].value).toEqual 'equity'
      expect(tokens[2].scopes).toEqual ['source.ledger', 'string.account']

    it "tokenizes commodities declared by commodity directive", ->
      {tokens} = grammar.tokenizeLine('commodity $')
      expect(tokens[2].value).toEqual '$'
      expect(tokens[2].scopes).toEqual ['source.ledger', 'string.commodity']

      {tokens} = grammar.tokenizeLine('commodity EUR')
      expect(tokens[2].value).toEqual 'EUR'
      expect(tokens[2].scopes).toEqual ['source.ledger', 'string.commodity']

  describe "transactions", ->
    it "tokenizes transactions", ->
      tokensByLines = grammar.tokenizeLines """
2015/01/01 1000 payee  ; comment
  foo   1.01  ; comment
  ; comment
  bar  -1.01
"""
      unclearedTransaction = ['source.ledger', 'meta.transaction.uncleared']
      expectedLine0 = [
        {'2015/01/01': unclearedTransaction.concat ['constant.numeric.date.transaction']}
        {' '         : unclearedTransaction}
        {'1000'      : unclearedTransaction.concat ['constant.numeric.transaction']}
        {' '         : unclearedTransaction}
        {'payee  '   : unclearedTransaction}
# TODO right trim payee
#        {'payee'     : unclearedTransaction.concat ['string.payee.transaction']}
#        {'  '        : unclearedTransaction}
        {'; comment' : unclearedTransaction.concat ['comment.transaction']}
      ]

      expect(tokensByLines[0].length).toEqual expectedLine0.length
      for token, index in expectedLine0
        for value, scopes of token
          expect(tokensByLines[0][index].value).toEqual value
          expect(tokensByLines[0][index].scopes).toEqual scopes

      postingTokens = unclearedTransaction.concat ['entity.transaction.posting']
      expectedLine1 = [
        {'  '        : postingTokens}
        {'foo'       : postingTokens.concat ['string.account']}
# TODO remove the following match double
        {' '         : postingTokens}
        {'  '        : postingTokens}
        {'1.01'      : postingTokens.concat ['constant.numeric.amount']}
        {'  '        : postingTokens}
        {'; comment' : postingTokens.concat ['comment.transaction']}
      ]

      expect(tokensByLines[1].length).toEqual expectedLine1.length
      for token, index in expectedLine1
        for value, scopes of token
          expect(tokensByLines[1][index].value).toEqual value
          expect(tokensByLines[1][index].scopes).toEqual scopes

    it "tokenizes flagged transactions", ->
      {tokens} = grammar.tokenizeLine '2015/01/01 ! 1000 payee  ; comment'

      pendingTransaction = ['source.ledger', 'meta.transaction.pending']
      expect(tokens[2].value).toEqual '!'
      expect(tokens[2].scopes).toEqual pendingTransaction.concat ['keyword.transaction.pending']

      {tokens} = grammar.tokenizeLine '2015/01/01 * 1000 payee  ; comment'

      clearedTransaction = ['source.ledger', 'meta.transaction.cleared']
      expect(tokens[2].value).toEqual '*'
      expect(tokens[2].scopes).toEqual clearedTransaction.concat ['keyword.transaction.cleared']

  xdescribe "indentation", ->
    editor = null

    beforeEach ->
      editor = new TextEditor({})
      editor.setGrammar(grammar)

    expectPreservedIndentation = (text) ->
      editor.setText(text)
      editor.autoIndentBufferRows(0, editor.getLineCount() - 1)

      expectedLines = text.split("\n")
      actualLines = editor.getText().split("\n")
      for actualLine, i in actualLines
        expect([
          actualLine,
          editor.indentLevelForLine(actualLine)
        ]).toEqual([
          expectedLines[i],
          editor.indentLevelForLine(expectedLines[i])
        ])

    it "indents allman-style curly braces", ->
      expectPreservedIndentation """
        if (true)
        {
          for (;;)
          {
            while (true)
            {
              x();
            }
          }
        }
        else
        {
          do
          {
            y();
          } while (true);
        }
      """

    it "indents non-allman-style curly braces", ->
      expectPreservedIndentation """
        if (true) {
          for (;;) {
            while (true) {
              x();
            }
          }
        } else {
          do {
            y();
          } while (true);
        }
      """

    it "indents collection literals", ->
      expectPreservedIndentation """
        [
          {
            a: b,
            c: d
          },
          e,
          f
        ]
      """

    it "indents function arguments", ->
      expectPreservedIndentation """
        f(
          g(
            h,
            i
          ),
          j
        );
      """
