module mux_2x1_4bit(in1,in2,out1,select);
  
  input wire [3:0] in1,in2;
  input wire select;
  output wire [3:0] out1;
  
  assign out1=(select)? in2 : in1;
  
endmodule
