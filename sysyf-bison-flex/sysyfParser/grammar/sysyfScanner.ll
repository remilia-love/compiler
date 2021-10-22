%{ /* -*- C++ -*- */
# include <cerrno>
# include <climits>
# include <cstdlib>
# include <cstring> // strerror
# include <string>
# include <algorithm>
# include <iostream>
# include <map>
# include "sysyfDriver.h"
# include "sysyfParser.h"
%}

%{
#if defined __clang__
# define CLANG_VERSION (__clang_major__ * 100 + __clang_minor__)
#endif

// Clang and ICC like to pretend they are GCC.
#if defined __GNUC__ && !defined __clang__ && !defined __ICC
# define GCC_VERSION (__GNUC__ * 100 + __GNUC_MINOR__)
#endif

// Pacify warnings in yy_init_buffer (observed with Flex 2.6.4)
// and GCC 6.4.0, 7.3.0 with -O3.
#if defined GCC_VERSION && 600 <= GCC_VERSION
# pragma GCC diagnostic ignored "-Wnull-dereference"
#endif

// This code uses Flex's C backend, yet compiles it as C++.
// So expect warnings about C style casts and NULL.
#if defined CLANG_VERSION && 500 <= CLANG_VERSION
# pragma clang diagnostic ignored "-Wold-style-cast"
# pragma clang diagnostic ignored "-Wzero-as-null-pointer-constant"
#elif defined GCC_VERSION && 407 <= GCC_VERSION
# pragma GCC diagnostic ignored "-Wold-style-cast"
# pragma GCC diagnostic ignored "-Wzero-as-null-pointer-constant"
#endif

#define FLEX_VERSION (YY_FLEX_MAJOR_VERSION * 100 + YY_FLEX_MINOR_VERSION)

// Old versions of Flex (2.5.35) generate an incomplete documentation comment.
//
//  In file included from src/scan-code-c.c:3:
//  src/scan-code.c:2198:21: error: empty paragraph passed to '@param' command
//        [-Werror,-Wdocumentation]
//   * @param line_number
//     ~~~~~~~~~~~~~~~~~^
//  1 error generated.
#if FLEX_VERSION < 206 && defined CLANG_VERSION
# pragma clang diagnostic ignored "-Wdocumentation"
#endif

// Old versions of Flex (2.5.35) use 'register'.  Warnings introduced in
// GCC 7 and Clang 6.
#if FLEX_VERSION < 206
# if defined CLANG_VERSION && 600 <= CLANG_VERSION
#  pragma clang diagnostic ignored "-Wdeprecated-register"
# elif defined GCC_VERSION && 700 <= GCC_VERSION
#  pragma GCC diagnostic ignored "-Wregister"
# endif
#endif

#if FLEX_VERSION < 206
# if defined CLANG_VERSION
#  pragma clang diagnostic ignored "-Wconversion"
#  pragma clang diagnostic ignored "-Wdocumentation"
#  pragma clang diagnostic ignored "-Wshorten-64-to-32"
#  pragma clang diagnostic ignored "-Wsign-conversion"
# elif defined GCC_VERSION
#  pragma GCC diagnostic ignored "-Wconversion"
#  pragma GCC diagnostic ignored "-Wsign-conversion"
# endif
#endif
%}

%option noyywrap nounput noinput batch debug

%{
  // Code run each time a pattern is matched.
  # define YY_USER_ACTION  loc.columns(yyleng);
%}

/* Regex abbreviations: */
/********add regular expression for MultilineComment, HexConst, FloatConst, SingleLineComment********/
MultilineComment		    "/*"([^\*]|(\*)*[^\*/])*(\*)*"*/"				
SingleLineComment		    "//".*$
Identifier              [_a-zA-Z][a-zA-Z0-9_]*
OctConst                ("0"[0-7]*)
DecConst                ([1-9][0-9]*)
HexConst                (("0x"|"0X")[0-9a-zA-Z]+)
FloatConst              ((([0-9]*[.][0-9]+)|([0-9]+[.]))([eE][-+]?[0-9]+)?)|([0-9]+[eE][-+]?[0-9]+)
Blank                   [ \t\r]
NewLine                 [\n]


%%
 /* keyword */
const       {return yy::sysyfParser::make_CONST(loc);}
int         {return yy::sysyfParser::make_INT(loc);}
void        {return yy::sysyfParser::make_VOID(loc);}
float       {return yy::sysyfParser::make_FLOAT(loc);}

return      {return yy::sysyfParser::make_RETURN(loc);}
if          {return yy::sysyfParser::make_IF(loc);}
else        {return yy::sysyfParser::make_ELSE(loc);}
while       {return yy::sysyfParser::make_WHILE(loc);}
continue    {return yy::sysyfParser::make_CONTINUE(loc);}
break       {return yy::sysyfParser::make_BREAK(loc);}

"=="        {return yy::sysyfParser::make_EQUEL(loc);}
"!="        {return yy::sysyfParser::make_NOEQUEL(loc);}
"<="        {return yy::sysyfParser::make_RELLEQ(loc);}
">="        {return yy::sysyfParser::make_RELGEQ(loc);}

[>]         {return yy::sysyfParser::make_RELG(loc);}
[<]         {return yy::sysyfParser::make_RELL(loc);}

[+]         {return yy::sysyfParser::make_PLUS(loc);}
[-]         {return yy::sysyfParser::make_MINUS(loc);}
[*]         {return yy::sysyfParser::make_MULTIPLY(loc);}
[/]         {return yy::sysyfParser::make_DIVIDE(loc);}
[%]         {return yy::sysyfParser::make_MODULO(loc);}
[=]         {return yy::sysyfParser::make_ASSIGN(loc);}
[;]         {return yy::sysyfParser::make_SEMICOLON(loc);}
[,]         {return yy::sysyfParser::make_COMMA(loc);}
[(]         {return yy::sysyfParser::make_LPARENTHESE(loc);}
[)]         {return yy::sysyfParser::make_RPARENTHESE(loc);}
[{]         {return yy::sysyfParser::make_LBRACE(loc);}
[}]         {return yy::sysyfParser::make_RBRACE(loc);}
[[]         {return yy::sysyfParser::make_LB(loc);}
[]]         {return yy::sysyfParser::make_RB(loc);}




 /* token and action */
{MultilineComment}				{std::string s = yytext;
                          size_t n = std::count(s.begin(), s.end(), '\n');
                          for (size_t i = 0; i < n; i++) loc.lines(1);}
{SingleLineComment}				/* ignore */
{Blank}+                {loc.step();}
{NewLine}+              {loc.lines(yyleng); loc.step();}
{DecConst}              {
                            std::string dec = yytext;
                            unsigned sum = 0;
                            int len = dec.size();
                            for(int i = 0;i < len;i++){
                                auto a = dec[i];
                                sum = sum * 10 + a - 48;
                            }
                            return yy::sysyfParser::make_INTCONST(int(sum),loc);
                        }
{OctConst}              {
                            std::string oct = yytext;
                            unsigned sum = 0;
                            int len = oct.size();
                            for(int i = 1;i < len;i++){
                                auto a = oct[i];
                                sum  = sum * 8 + a - 48;
                            }
                            return yy::sysyfParser::make_INTCONST(int(sum),loc);
                        }
{HexConst}              {
                            std::string oct = yytext;
                            unsigned sum = 0;
                            int len = oct.size();
                            for(int i = 2;i < len;i++){
                                auto a = oct[i];
                                int tmp = 0;
                                if(a == 'a' || a == 'A') tmp = 10;
                                else if(a == 'b' || a == 'B') tmp = 11;
                                else if(a == 'c' || a == 'C') tmp = 12;
                                else if(a == 'd' || a == 'D') tmp = 13;
                                else if(a == 'e' || a == 'E') tmp = 14;
                                else if(a == 'f' || a == 'F') tmp = 15;
                                else tmp = a - 48;
                                sum  = sum * 16 + tmp;
                            }
                            return yy::sysyfParser::make_INTCONST(int(sum),loc);
                        }
{FloatConst}              {return yy::sysyfParser::make_FLOATCONST(std::stod(yytext),loc);}
{Identifier}            {return yy::sysyfParser::make_IDENTIFIER(yytext, loc);}
<<EOF>>                     {return yy::sysyfParser::make_END(loc);}
.                           {std::cout << "Error in scanner!" << '\n'; exit(1);}
%%

int yyFlexLexer::yylex() {
    std::cerr << "'int yyFlexLexer::yylex()' should never be called." << std::endl;
    exit(1);
}
