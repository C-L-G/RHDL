/*
  ע��.....
 
*/

`timescale ... ��verilog��һ��   // ˫б��Ҳ����ע��

module XXXX (	//ģ�鶨��
	input    	A,
    input[1:0]	B,
	output[1:0]	C,	//�˿ڶ���
	inout		D,

	interface   E	//�ӿڶ���
);

//��һ�ַ�ʽ

module XXXX #(
	parameter	DSIZE = 0	,	//��������
	list_par	G	= O			//�����б���
)(	//ģ�鶨��
	input    	A,
    input[1:0]	B,
	output[1:0]	C,	//�˿ڶ���
	inout		D,

	interface   E	//�ӿڶ���
);


����߼������

comb_block:������	
...
end_comb_block:������(�����ֿ�ѡ)


ʱ���߼������

ff_block@ʱ�Ӻ͸�λ:������
...
end_ff_block:������(�����ֿ�ѡ)

�����ʹ��
1)������������,����������ݴ����Զ������wire�ͻ�reg��,���Զ�����λ��
2)�����ͷ����������� = ��ֵ
�������������������ʾ����

1)�����Ը�ֵ
2)�����ڲ�ͬblock�ڸ�ֵ
3)ֻ�б���ֵ(ֻ�����ڵȺ����)
4)û�б���ֵ(ֻ�����ڵȺ��ұ�)
comb_block:A_block
	a = b;		//������ֵ
	b = c&d;	//�߼����㸳ֵ���̳�verilog�ķ�ʽ
	z = x? y : d;	
	
	if d		// if ���
	begin
		e[0:1] = f[1:0];	//����ѡ��range
		e = f;				//�����Ը�ֵ��֧��
	end
	else
	begin
		e[1:0] = ~f[0:1];//ͬʱ���Է�ѡ
	end

	case(x)		// case �﷨ 
	0:	f = g;
	1:	f = g + 1;
	default:
		f = 0;
	endcase
end_comb_block:A_block

ff_block@ʱ�Ӻ͸�λ:B_block
	h = j;		//������ֵ��������ֵ���� = 
	
	if j		//if ���
		i = ~i;
	else
		i = i;

	case		// case����verilogһ��
	...	
	endcase
ff_block:B_block


endmodule //ģ�������־
	
	
		