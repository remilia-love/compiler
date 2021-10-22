 ## 1-1

### main函数

先实例化词法/语法分析器接口类demoDriver和语法树打印类SyntaxTreePrinter，并用标准错误初始化错误打印器ErrorReporter。之后默认不打印ast树

~~~cpp
    demoDriver driver;
    SyntaxTreePrinter printer;
    ErrorReporter reporter(std::cerr);

    bool print_ast = false;
~~~


接受命令行参数并处理，其中-p和-s参数指定是否输出语法/词法分析详情，被传入分析器实例中用作进一步分析

~~~cpp
    std::string filename = "testcase.sy";
    for (int i = 1; i < argc; ++i) {
        if (argv[i] == std::string("-h") || argv[i] == std::string("--help")) {
            print_help(argv[0]);
            return 0;
        }
        else if (argv[i] == std::string("-p") || argv[i] == std::string("--trace_parsing"))
            driver.trace_parsing = true;
        else if (argv[i] == std::string("-s") || argv[i] == std::string("--trace_scanning"))
            driver.trace_scanning = true;
        else if (argv[i] == std::string("-emit-ast"))
            print_ast = true;
        else {
            filename = argv[i];
        }
    }

~~~
使用分析器的parse方法传入待分析的文件名，进行语法/词法分析，返回分析树。

如果指定-emit-ast，会将print_ast置为真，从而触发打印器。

~~~cpp
    auto root = driver.parse(filename);
    if(print_ast)
        root->accept(printer);
    return 0;
~~~

跟进driver这个实例。

### demoDriver.cpp

定义分析器接口方法的构造和析构函数，默认不展示词法/语法分析的详细过程

~~~cpp
demoDriver::demoDriver()
    : trace_scanning(false), trace_parsing(false)
{
}

demoDriver::~demoDriver()
{
}
~~~

定义语法分析器的parse函数，将传入的文件路径传入file属性，开启词法和语法分析程序。

~~~cpp
SyntaxTree::Node* demoDriver::parse(const std::string &f)
{
    file = f;

    // lexer begin
    scan_begin();
    yy::demoParser parser(*this);
    parser.set_debug_level(trace_parsing);
    // parser begin
    parser.parse();
    // lexer end
    scan_end();

    return this->root;
}
~~~

scan_begin函数设置好trace_scanning(与设置的-s参数有关)后，将文件打开为输入流，如果文件路径为'-'，则将标准输入打开为输入流(即读取用户在命令行输入的代码字符)。之后将输入流传入分析器的switch_streams()函数中做词法分析。

scan_end用于分析结束后关闭输入流。

~~~cpp
void demoDriver::scan_begin()
{
    lexer.set_debug(trace_scanning);

    // Try to open the file:
    instream.open(file);

    if(instream.good()) {
        lexer.switch_streams(&instream, 0);
    }
    else if(file == "-") {
        lexer.switch_streams(&std::cin, 0);
    }
    else {
        error("Cannot open file '" + file + "'.");
        exit(EXIT_FAILURE);
    }
}

void demoDriver::scan_end()
{
    instream.close();
}
~~~

### demoDriver.h

头文件中存放了分析器类demoDriver的定义。

这里引入了几个头文件，用于调用词法/语法分析方法/分析类，以及导入SyntaxTree命名空间。

~~~cpp
#include "../build/demoParser.h"

#include "demoFlexLexer.h"
#include "SyntaxTree.h"
~~~

这里声明了构造和析构函数，函数在之前分析的.cpp文件中被定义。

~~~cpp
    demoDriver();
    virtual ~demoDriver();
    
~~~

这里声明了很多.cpp里被调用的方法和属性，具体用途前面都分析过了。

~~~cpp
    // demo lexer
    demoFlexLexer lexer;

    std::ifstream instream;

    // Handling the demo scanner.
    void scan_begin();
    void scan_end();
    bool trace_scanning;
    
    // Run the parser on file F.
    // Return 0 on success.
    SyntaxTree::Node* parse(const std::string& f);
    // The name of the file being parsed.
    // Used later to pass the file name to the location tracker.
    std::string file;
    // Whether parser traces should be generated.
    bool trace_parsing;
~~~

到这里就很清楚了，这个demoFlexLexer是真正的词法分析器类，之前的demoDriver只是对其以及语法分析器的一个封装，是一个与用户输入交互的接口。而语法分析器类没有在这个文件中出现。




 ## 1-2

在demoScanner.ll的%%后定义关键字main

 ```txt
 main        {return yy::demoParser::make_MAIN(loc);}
 ```

同时在demoParser.yy中token非终结符MAIN。

```
%token MAIN
```

最后修改demoParser.yy中144行的语句，改IDENTIFIER为MAIN即可。

```
// 下一行中的MAIN原来是IDENTIFIER
FuncDef: VOID MAIN LPARENTHESE RPARENTHESE Block{
    $$ = new SyntaxTree::FuncDef();
    $$->ret_type = SyntaxTree::Type::VOID;
    $$->name = $2;
    $$->body = SyntaxTree::Ptr<SyntaxTree::BlockStmt>($5);
    $$->loc = @$;
  }
  ;
```
