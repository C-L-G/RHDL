module  XXXX
// comment
`IF X
    localparam XXX  //comment
    endlocalparam
`ELSIF YY
    localparam BB
    endlocalparam
    /* comment */
`ENDIF
/* comment */
comb CCC
// comment
endcomb

ffblock FF
/* comment */
endff

interface IIII
    input III //
    output III
    input [X:X]III
    inout III [X:X]
    /* xxxxx */
    output [XX:XX] III [XX:XX]
endinterface

parameter XXXX

endparameter


endmodule
