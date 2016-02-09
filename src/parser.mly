%{ 
open Ast
%}

/* OCamlyacc Declarations */

%token EOF
%token PLUS MINUS MULTIPLY DIVIDE MODULUS
%token LT LTE GT GTE EQUALS NEQ
%token AND OR NOT
%token LPAREN RPAREN LBRACE RBRACE RSQUARE LSQUARE
%token ASSIGN
%token CARET
%token VAL IF THEN ELSE DEF TRUE FALSE
%token NUM LIST BOOL STRING UNIT
%token COLON SEMICOLON DOT FATARROW COMMA THINARROW

%token <float> NUM_LIT
%token <string> STR_LIT
%token <string> MOD_LIT
%token <string> ID

/* associativity rules */
%left ASSIGN
%left PLUS MINUS
%left MULTIPLY DIVIDE MODULUS


%start expr
%type <Ast.expr> expr

%%

/* grammar follows */
expr: 
    | expr PLUS expr { Binop($1, Add, $3) }
    | expr MINUS expr { Binop($1, Sub, $3) }
    | expr MULTIPLY expr { Binop($1, Mul, $3) }
    | expr DIVIDE expr { Binop($1, Div, $3) }
    | expr MODULUS expr { Binop($1, Mod, $3) }
    | NUM_LIT { NumLit($1) }
    | ID { Val($1) }
    | VAL ID COLON NUM ASSIGN expr { Assign($2, Num, $6) }
    | VAL ID COLON BOOL ASSIGN expr { Assign($2, Bool, $6) }
    | VAL ID COLON STRING ASSIGN expr { Assign($2, String, $6) }
    | VAL ID COLON UNIT ASSIGN expr { Assign($2, Unit, $6) }

