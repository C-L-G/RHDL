/*
  注释.....
 
*/

`timescale ... 和verilog的一样   // 双斜杠也可以注释

module XXXX (	//模块定义
	input    	A,
    input[1:0]	B,
	output[1:0]	C,	//端口定义
	inout		D,

	interface   E	//接口定义
);

//另一种方式

module XXXX #(
	parameter	DSIZE = 0	,	//参数定义
	list_par	G	= O			//参数列表定义
)(	//模块定义
	input    	A,
    input[1:0]	B,
	output[1:0]	C,	//端口定义
	inout		D,

	interface   E	//接口定义
);


组合逻辑代码块

comb_block:块名字	
...
end_comb_block:块名字(块名字可选)


时序逻辑代码块

ff_block@时钟和复位:块名字
...
end_ff_block:块名字(块名字可选)

代码块使用
1)变量不用声明,解析器会根据代码自动定义成wire型或reg型,并自动定义位宽
2)阻塞和非阻塞都是用 = 赋值
以下情况，解析器会提示错误

1)覆盖性赋值
2)变量在不同block内赋值
3)只有被赋值(只出现在等号左边)
4)没有被赋值(只出现在等号右边)
comb_block:A_block
	a = b;		//正常赋值
	b = c&d;	//逻辑运算赋值，继承verilog的方式
	z = x? y : d;	
	
	if d		// if 语句
	begin
		e[0:1] = f[1:0];	//可以选择range
		e = f;				//覆盖性赋值不支持
	end
	else
	begin
		e[1:0] = ~f[0:1];//同时可以反选
	end

	case(x)		// case 语法 
	0:	f = g;
	1:	f = g + 1;
	default:
		f = 0;
	endcase
end_comb_block:A_block

ff_block@时钟和复位:B_block
	h = j;		//阻塞赋值非阻塞赋值都用 = 
	
	if j		//if 语句
		i = ~i;
	else
		i = i;

	case		// case语句和verilog一致
	...	
	endcase
ff_block:B_block


endmodule //模块结束标志
	
	
		