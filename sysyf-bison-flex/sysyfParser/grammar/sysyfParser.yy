%skeleton "lalr1.cc" /* -*- c++ -*- */
%require "3.0"
%defines
//%define parser_class_name {sysyfParser}
%define api.parser.class {sysyfParser}

%define api.token.constructor
%define api.value.type variant
%define parse.assert

%code requires
{
#include <string>
#include "SyntaxTree.h"
class sysyfDriver;
}

// The parsing context.
%param { sysyfDriver& driver }

// Location tracking
%locations
%initial-action
{
// Initialize the initial location.
@$.begin.filename = @$.end.filename = &driver.file;
};

// Enable tracing and verbose errors (which may be wrong!)
%define parse.trace
%define parse.error verbose

// Parser needs to know about the driver:
%code
{
#include "sysyfDriver.h"
#define yylex driver.lexer.yylex
}

// Tokens:
%define api.token.prefix {TOK_}

%token END
%token CONST
%token EQUEL NOEQUEL
%token RELLEQ RELGEQ RELL RELG
%token PLUS MINUS MULTIPLY DIVIDE MODULO
%token ASSIGN SEMICOLON
%token COMMA LPARENTHESE RPARENTHESE
%token LBRACE RBRACE
%token LB RB
%token INT FLOAT VOID
%token RETURN IF ELSE CONTINUE BREAK WHILE
%token <std::string>IDENTIFIER
%token <int>INTCONST
%token <float>FLOATCONST
%token EOL COMMENT
%token BLANK NOT



// Use variant-based semantic values: %type and %token expect genuine types
// 全局结点相关
%type <SyntaxTree::Assembly*>CompUnit
%type <SyntaxTree::PtrList<SyntaxTree::GlobalDef>>GlobalDecl

// 变量定义相关
%type <SyntaxTree::Type>BType
%type <SyntaxTree::PtrList<SyntaxTree::VarDef>>VarDecl
%type <SyntaxTree::PtrList<SyntaxTree::VarDef>>VarDefList
%type <SyntaxTree::VarDef*>VarDef
%type <SyntaxTree::InitVal*>InitVal
%type <SyntaxTree::PtrList<SyntaxTree::Expr>>VarHelper
%type <SyntaxTree::PtrList<SyntaxTree::VarDef>>ConstDecl
%type <SyntaxTree::PtrList<SyntaxTree::VarDef>>ConstDefList
%type <SyntaxTree::VarDef*>ConstDef
%type <SyntaxTree::InitVal*>ConstInitVal

// 函数定义相关
%type <SyntaxTree::FuncDef*>FuncDef
%type <SyntaxTree::FuncFParamList*> FuncFParamList
%type <SyntaxTree::FuncParam*> FuncFParam

%type <SyntaxTree::BlockStmt*>Block
%type <SyntaxTree::PtrList<SyntaxTree::Stmt>>BlockItemList
%type <SyntaxTree::PtrList<SyntaxTree::Stmt>>BlockItem
%type <SyntaxTree::Stmt*>Stmt
%type <SyntaxTree::Stmt*>ELSEHelper
%type <SyntaxTree::IfStmt*>IfStmt
%type <SyntaxTree::WhileStmt*>WhileStmt
%type <SyntaxTree::BreakStmt*>BreakStmt
%type <SyntaxTree::ContinueStmt*>ContinueStmt
%type <SyntaxTree::ReturnStmt*>ReturnStmt

// 表达式相关
%type <SyntaxTree::LVal*>LVal

%type <SyntaxTree::Expr*>AddExp

%type <SyntaxTree::Expr*>ConstExp
%type <SyntaxTree::PtrList<SyntaxTree::InitVal>>ConstInitValList

%type <SyntaxTree::Expr*> Exp
%type <SyntaxTree::Expr*> PrimaryExp
%type <SyntaxTree::PtrList<SyntaxTree::InitVal>>InitValList

%type <SyntaxTree::Expr*> UnaryExp
%type <SyntaxTree::Expr*> MulExp

%type <SyntaxTree::Expr*> RelExp
%type <SyntaxTree::Expr*> CondExp
%type <SyntaxTree::Expr*> OptionExp
%type <SyntaxTree::Literal*>Number
%type <SyntaxTree::UnaryOp> UnaryOp
%type <SyntaxTree::BinOp> MulOp
%type <SyntaxTree::BinOp> AddOp
%type <SyntaxTree::BinaryCondOp> TOp
%type <SyntaxTree::BinaryCondOp> eOp

%type <SyntaxTree::FuncCallStmt*> FuncCall
%type <SyntaxTree::PtrList<SyntaxTree::Expr>>FuncRParamList




// No %destructors are needed, since memory will be reclaimed by the
// regular destructors.

// Grammar:
%start Begin 

%%
Begin: CompUnit END {
    $1->loc = @$;
    driver.root = $1;
    return 0;
  }
  ;

CompUnit:CompUnit GlobalDecl{
		$1->global_defs.insert($1->global_defs.end(), $2.begin(), $2.end());
		$$=$1;
	} 
	| GlobalDecl{
		$$=new SyntaxTree::Assembly();
		$$->global_defs.insert($$->global_defs.end(), $1.begin(), $1.end());
  }
	;

GlobalDecl: ConstDecl{
  $$ = SyntaxTree::PtrList<SyntaxTree::GlobalDef>();
  $$.insert($$.end(), $1.begin(), $1.end());
}
  | VarDecl{
  $$ = SyntaxTree::PtrList<SyntaxTree::GlobalDef>();
  $$.insert($$.end(), $1.begin(), $1.end());
}
  | FuncDef{
  $$ = SyntaxTree::PtrList<SyntaxTree::GlobalDef>();
  $$.push_back(SyntaxTree::Ptr<SyntaxTree::GlobalDef>($1));
}
  ;

// 常量声明
ConstDecl: CONST BType ConstDefList SEMICOLON{
  $$ = $3;
  for(auto &value : $$){
    value->btype = $2;
  }
}
  ;

ConstDefList: ConstDefList COMMA ConstDef{
  $1.push_back(SyntaxTree::Ptr<SyntaxTree::VarDef>($3));
  $$ = $1;
}
  | ConstDef{
    $$ = SyntaxTree::PtrList<SyntaxTree::VarDef>();
    $$.push_back(SyntaxTree::Ptr<SyntaxTree::VarDef>($1));
  }
  ;

BType: INT{
  $$=SyntaxTree::Type::INT;
  }
  | FLOAT{
  $$=SyntaxTree::Type::FLOAT;
  }
  ;

ConstDef: IDENTIFIER LB ConstExp RB  ASSIGN ConstInitVal{
    $$ = new SyntaxTree::VarDef();
    $$->name = $1;
    $$->is_constant = true;
    auto tmp = SyntaxTree::PtrList<SyntaxTree::Expr>();
    tmp.push_back(SyntaxTree::Ptr<SyntaxTree::Expr>($3));
    $$->array_length = tmp;
    $$->initializers = SyntaxTree::Ptr<SyntaxTree::InitVal>($6);
    $$->is_inited = true;
    $$->loc = @$;
  }
  | IDENTIFIER  ASSIGN ConstInitVal{
    $$ = new SyntaxTree::VarDef();
    $$->name = $1;
    $$->is_constant = true;
    $$->initializers = SyntaxTree::Ptr<SyntaxTree::InitVal>($3);
    $$->is_inited = true;
    $$->loc = @$;
  }
  ;

ConstInitVal: ConstExp{
  $$ = new SyntaxTree::InitVal();
  $$->isExp = true;
  $$->expr = SyntaxTree::Ptr<SyntaxTree::Expr>($1);
}
  | LBRACE ConstInitValList RBRACE{
    $$ = new SyntaxTree::InitVal();
    $$->isExp = false;
    $$->elementList = SyntaxTree::PtrList<SyntaxTree::InitVal>($2);
  }
  ;

ConstInitValList: ConstInitValList COMMA ConstInitVal{
  $1.push_back(SyntaxTree::Ptr<SyntaxTree::InitVal>($3));
  $$ = $1;
}
  | ConstInitVal{
    $$ = SyntaxTree::PtrList<SyntaxTree::InitVal>();
    $$.push_back(SyntaxTree::Ptr<SyntaxTree::InitVal>($1));
  }
  | %empty{
    $$ = SyntaxTree::PtrList<SyntaxTree::InitVal>();
  }
  ;



// 变量声明
VarDecl: BType VarDefList SEMICOLON{
  $$ = $2;
  for(auto &value : $$){
    value->btype = $1;
  }
}
  ;

VarDefList: VarDefList COMMA VarDef{
  $1.push_back(SyntaxTree::Ptr<SyntaxTree::VarDef>($3));
  $$ = $1;
}
  | VarDef{
    $$ = SyntaxTree::PtrList<SyntaxTree::VarDef>();
    $$.push_back(SyntaxTree::Ptr<SyntaxTree::VarDef>($1));
  }
  ;

VarDef: IDENTIFIER VarHelper ASSIGN InitVal{
  $$ = new SyntaxTree::VarDef();
  $$->name = $1;
  $$->is_constant = false;
  $$->is_inited = true;
  $$->initializers = SyntaxTree::Ptr<SyntaxTree::InitVal>($4);
  $$->array_length = $2;
  $$->loc = @$;
}
  | IDENTIFIER VarHelper{
    $$ = new SyntaxTree::VarDef();
    $$->name = $1;
    $$->is_constant = false;
    $$->is_inited = false;
    $$->array_length = $2;
    $$->loc = @$;
  }
  ;

VarHelper:  VarHelper LB ConstExp RB {
  $1.push_back(SyntaxTree::Ptr<SyntaxTree::Expr>($3));
  $$ = $1;
}
  | %empty{
    $$ = SyntaxTree::PtrList<SyntaxTree::Expr>();
  }
  ;

InitVal: Exp{
  $$ = new SyntaxTree::InitVal();
  $$->isExp = true;
  $$->expr = SyntaxTree::Ptr<SyntaxTree::Expr>($1);
}
  | LBRACE InitValList RBRACE{
    $$ = new SyntaxTree::InitVal();
    $$->isExp = false;
    $$->elementList = SyntaxTree::PtrList<SyntaxTree::InitVal>($2);
  }
  ;

InitValList: InitValList COMMA InitVal{
  $1.push_back(SyntaxTree::Ptr<SyntaxTree::InitVal>($3));
  $$ = $1;
}
  | InitVal{
    $$ = SyntaxTree::PtrList<SyntaxTree::InitVal>();
    $$.push_back(SyntaxTree::Ptr<SyntaxTree::InitVal>($1));
  }
  | %empty{
    $$ = SyntaxTree::PtrList<SyntaxTree::InitVal>();
  }
  ;


// 函数定义
FuncDef: BType IDENTIFIER LPARENTHESE FuncFParamList RPARENTHESE Block{
    $$ = new SyntaxTree::FuncDef();
    $$->ret_type = $1;
    $$->param_list = SyntaxTree::Ptr<SyntaxTree::FuncFParamList>($4);
    $$->name = $2;
    $$->body = SyntaxTree::Ptr<SyntaxTree::BlockStmt>($6);
    $$->loc = @$;
  }
  ;

FuncFParamList: FuncFParamList COMMA FuncFParam{
  auto tmp = $1->params;
  tmp.push_back(SyntaxTree::Ptr<SyntaxTree::FuncParam>($3));
  $1->params = tmp;
  $$ = $1;
}
  | FuncFParam{
    $$ = new SyntaxTree::FuncFParamList();
    ($$->params).push_back(SyntaxTree::Ptr<SyntaxTree::FuncParam>($1));
  }
  | %empty{
    $$ = new SyntaxTree::FuncFParamList();
  }
  ;

FuncFParam: BType IDENTIFIER{
  $$ = new SyntaxTree::FuncParam();
  $$->name = $2;
  $$->param_type = $1;
  $$->loc = @$;
};

Block:LBRACE BlockItemList RBRACE{
    $$ = new SyntaxTree::BlockStmt();
    $$->body = $2;
    $$->loc = @$;
  }
  ;


BlockItemList:BlockItemList BlockItem{
    $1.insert($1.end(), $2.begin(), $2.end());
    $$ = $1;
  }
  | %empty{
    $$ = SyntaxTree::PtrList<SyntaxTree::Stmt>();
  }
  ;

BlockItem: ConstDecl{
    $$ = SyntaxTree::PtrList<SyntaxTree::Stmt>();
    $$.insert($$.end(), $1.begin(), $1.end());
  }
  | VarDecl{
    $$ = SyntaxTree::PtrList<SyntaxTree::Stmt>();
    $$.insert($$.end(), $1.begin(), $1.end());
  }
  | Stmt{
    $$ = SyntaxTree::PtrList<SyntaxTree::Stmt>();
    $$.push_back(SyntaxTree::Ptr<SyntaxTree::Stmt>($1));
  }
  ;

Stmt: LVal ASSIGN Exp SEMICOLON{
    auto temp = new SyntaxTree::AssignStmt();
    temp->target = SyntaxTree::Ptr<SyntaxTree::LVal>($1);
    temp->value = SyntaxTree::Ptr<SyntaxTree::Expr>($3);
    $$ = temp;
    $$->loc = @$;
  }
  | Exp SEMICOLON{
    auto temp = new SyntaxTree::ExprStmt();
    temp->exp = SyntaxTree::Ptr<SyntaxTree::Expr>($1);
    $$ = temp;
    $$->loc = @$;
  }
  | SEMICOLON{
    $$ = new SyntaxTree::EmptyStmt();
    $$->loc = @$;
  }
  | Block{
    $$ = $1;
  }
  | IfStmt{
    $$ = $1;
  }
  | WhileStmt{
    $$ = $1;
  }
  | BreakStmt{
    $$ = $1;
  }
  | ContinueStmt{
    $$ = $1;
  }
  | ReturnStmt{
    $$ = $1;
  }
  ;

IfStmt: IF LPARENTHESE CondExp RPARENTHESE Stmt ELSEHelper{
  auto tmp = new SyntaxTree::IfStmt();
  tmp->cond_exp = SyntaxTree::Ptr<SyntaxTree::Expr>($3);
  tmp->if_statement = SyntaxTree::Ptr<SyntaxTree::Stmt>($5);
  tmp->else_statement = SyntaxTree::Ptr<SyntaxTree::Stmt>($6);
  $$ = tmp;
  $$->loc = @$;
};

ELSEHelper: ELSE Stmt{
  $$ = $2;
}
  | %empty{
    $$ = nullptr;
  };

WhileStmt: WHILE LPARENTHESE CondExp RPARENTHESE Stmt{
  auto tmp = new SyntaxTree::WhileStmt();
  tmp->cond_exp = SyntaxTree::Ptr<SyntaxTree::Expr>($3);
  tmp->statement = SyntaxTree::Ptr<SyntaxTree::Stmt>($5);
  $$ = tmp;
  $$->loc = @$;
};

BreakStmt: BREAK SEMICOLON{
  $$ = new SyntaxTree::BreakStmt();
  $$->loc = @$;
};

ContinueStmt: CONTINUE SEMICOLON{
  $$ = new SyntaxTree::ContinueStmt();
  $$->loc = @$;
};

ReturnStmt: RETURN OptionExp SEMICOLON{
  $$ = new SyntaxTree::ReturnStmt();
  $$->ret = SyntaxTree::Ptr<SyntaxTree::Expr>($2);
  $$->loc = @$;
};

OptionExp: Exp{
  $$ = $1;
}
  | %empty{
    $$ = nullptr;
  }
  ;

// 表达式定义
LVal: IDENTIFIER VarHelper{
  $$ = new SyntaxTree::LVal();
  $$->name = $1;
  $$->array_index = $2;
  $$->loc = @$;
}

Exp: AddExp{
  $$ = $1;
};

PrimaryExp: LPARENTHESE Exp RPARENTHESE{
  $$ = $2;
}
  | LVal{
    $$ = $1;
  }
  | Number{
      $$ = $1;
  }
  ;

UnaryExp: PrimaryExp{
    $$ = $1;
}
  | FuncCall{
      $$ = $1;
  }
  | UnaryOp UnaryExp{
    auto tmp = new SyntaxTree::UnaryExpr();
    tmp->op = $1;
    tmp->rhs = SyntaxTree::Ptr<SyntaxTree::Expr>($2);
    $$ = tmp;
    $$->loc = @$;
  }
  ;

Number: INTCONST{
  $$ = new SyntaxTree::Literal();
  $$->literal_type = SyntaxTree::Type::INT;
  $$->int_const = $1;
  $$->loc = @$;
}
  | FLOATCONST{
  $$ = new SyntaxTree::Literal();
  $$->literal_type = SyntaxTree::Type::FLOAT;
  $$->float_const = $1;
  $$->loc = @$;
}
  ;

FuncCall: IDENTIFIER LPARENTHESE FuncRParamList RPARENTHESE{
  $$ = new SyntaxTree::FuncCallStmt();
  $$->name = $1;
  $$->params = $3;
  $$->loc = @$;
};

FuncRParamList: FuncRParamList COMMA Exp{
  $1.push_back(SyntaxTree::Ptr<SyntaxTree::Expr>($3));
  $$ = $1;
}
  | Exp{
    $$ = SyntaxTree::PtrList<SyntaxTree::Expr>();
    $$.push_back(SyntaxTree::Ptr<SyntaxTree::Expr>($1));
  }
  | %empty{
    $$ = SyntaxTree::PtrList<SyntaxTree::Expr>();
  }
  ;

UnaryOp: PLUS{
  $$ = SyntaxTree::UnaryOp::PLUS;
}
  | MINUS{
  $$ = SyntaxTree::UnaryOp::MINUS;
}
  ;

ConstExp: AddExp{
  $$ = $1;
};

MulExp: MulExp MulOp UnaryExp{
    auto temp = new SyntaxTree::BinaryExpr();
    temp->op = $2;
    temp->lhs = SyntaxTree::Ptr<SyntaxTree::Expr>($1);
    temp->rhs = SyntaxTree::Ptr<SyntaxTree::Expr>($3);
    $$ = temp;
    $$->loc = @$;
  }
  | UnaryExp{
    $$ = $1;
  }
  ;

AddExp: AddExp AddOp MulExp{
    auto temp = new SyntaxTree::BinaryExpr();
    temp->op = $2;
    temp->lhs = SyntaxTree::Ptr<SyntaxTree::Expr>($1);
    temp->rhs = SyntaxTree::Ptr<SyntaxTree::Expr>($3);
    $$ = temp;
    $$->loc = @$;
  }
  | MulExp{
    $$ = $1;
  }
  ;

MulOp: MULTIPLY{
  $$ = SyntaxTree::BinOp::MULTIPLY;
}
  | DIVIDE{
  $$ = SyntaxTree::BinOp::DIVIDE;
}
  | MODULO{
  $$ = SyntaxTree::BinOp::MODULO;
}
  ;

AddOp: PLUS{
  $$ = SyntaxTree::BinOp::PLUS;
}
  | MINUS{
  $$ = SyntaxTree::BinOp::MINUS;
}
  ;

TOp: RELLEQ{
  $$ = SyntaxTree::BinaryCondOp::LTE;
}
  | RELGEQ{
  $$ = SyntaxTree::BinaryCondOp::GTE;
}
  | RELL{
  $$ = SyntaxTree::BinaryCondOp::LT;
}
  | RELG{
  $$ = SyntaxTree::BinaryCondOp::GT;
}
  ;

eOp: EQUEL{
  $$ = SyntaxTree::BinaryCondOp::EQ;
}
  | NOEQUEL{
  $$ = SyntaxTree::BinaryCondOp::NEQ;
}
  ;

RelExp: RelExp TOp AddExp{
    auto temp = new SyntaxTree::BinaryCondExpr();
    temp->op = $2;
    temp->lhs = SyntaxTree::Ptr<SyntaxTree::Expr>($1);
    temp->rhs = SyntaxTree::Ptr<SyntaxTree::Expr>($3);
    $$ = temp;
    $$->loc = @$;
  }
  | AddExp{
    $$ = $1;
  }
  ;

CondExp: CondExp eOp RelExp{
    auto temp = new SyntaxTree::BinaryCondExpr();
    temp->op = $2;
    temp->lhs = SyntaxTree::Ptr<SyntaxTree::Expr>($1);
    temp->rhs = SyntaxTree::Ptr<SyntaxTree::Expr>($3);
    $$ = temp;
    $$->loc = @$;
  }
  | RelExp{
    $$ = $1;
  }
  ;


%%

// Register errors to the driver:
void yy::sysyfParser::error (const location_type& l,
                          const std::string& m)
{
    driver.error(l, m);
}
