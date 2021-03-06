module final_datapath();
  
  parameter id_control_width=10;
  parameter exec_control_width=10;
  parameter mem_control_width=7;
  parameter wb_control_width=2;
  
  reg clock;
  
  wire [31:0] inst_frm_inst_mem,inst,pc_current,inst_write_data;
  wire inst_rd,pc_wr,mod_clock;
  wire [id_control_width-1:0] id_control;
  wire [exec_control_width-1:0] exec_control_id_phase;
  wire [mem_control_width-1:0] mem_control_id_phase;
  wire [wb_control_width-1:0] wb_control_id_phase; 
  
  wire [3:0] rs1_add,rs4_add;
  
  wire [31:0] reg_updt_data_wb,wb_data_wb,pc_next1,pc_current_minus8,rs1_after_mux,rs4_after_mux;
  wire [3:0] reg_updt_add_wb,wb_add_wb;
  wire [wb_control_width-1:0] wb_control_wb;
  wire [31:0] out1_file,out2_file,out3_file,out4_file;
  wire stall;
  
  mux_2x1_4bit src1_add_mux1_unit(inst[19:16],{4'b1110},rs1_add,id_control[9]);
  mux_2x1_4bit dest_add_mux2_unit(inst[15:12],{4'b1111},rs4_add,id_control[8]);
  
  subtractor sub_unit1(pc_current,pc_current_minus8);
  mux_2x1_32bit rs1_pc_content_mux3_unit(out1_file,pc_current_minus8,id_control[1],rs1_after_mux);
  mux_2x1_32bit swp_rs2_rs4_mux8_unit(out4_file,out2_file,id_control[0],rs4_after_mux);
  
  //WRITE BACK CONTROLS wb_control={wr,reg_update}
  
  //READ REGISTER CONTROL  9->scr1_add_mux1,8->dest_add_mux2,7->rd1,6->rd2,5->rd3,4->rd4,3->set_write_bit,
  //2->set_reg_update,1->rs1_pc_content_mux3,0->swp_rs2_rs4_mux8;
  
  //wire inst_rd;
  and a1(inst_rd,clock,~stall);
  and a2(pc_wr,~clock,~stall);
  and a3(mod_clock,clock,~stall);
   
  instruction_memory inst_mem1(.inst_address(pc_current),.inst_read(inst_rd),.inst_write(inst_wr),
  .inst_write_data(inst_write_data),.inst_out(inst_frm_inst_mem));
  
  inst_reg_pipeline inst_reg_pipe1(.clock(mod_clock),.inst_in(inst_frm_inst_mem),.inst_out(inst));
  
  
  //ID phase starts
  
  
  main_control_unit mcu1(.inst({inst[27:20],inst[7:4]}),.clock(clock),.reg_rd_control(id_control),
  .exec_control(exec_control_id_phase),.mem_control(mem_control_id_phase),.wb_control(wb_control_id_phase));
  
  pc_incrementer pc_inc1(pc_current,pc_next1);
  
  reg_file reg_file1(.clock(clock),.read_1(id_control[7]),.read_2(id_control[6]),.read_3(id_control[5]),.read_4(id_control[4]),
  .write(wb_control_wb[1]),.write_pc(pc_wr),.reg_update(wb_control_wb[0]),
  .set_write_bit(id_control[3]),.set_reg_update(id_control[2]),.src1_add(rs1_add),
  .src2_add(inst[3:0]),.src3_add(inst[11:8]),.dest_add(rs4_add),.reg_update_data(reg_updt_data_wb)
  ,.data_write(wb_data_wb),.pc_next(pc_next1),.reg_update_address(reg_updt_add_wb),.write_back_address(wb_add_wb),
  .pc_content(pc_current),.out_src1(out1_file),.out_src2(out2_file),.out_src3(out3_file),.out_src4(out4_file),.stall(stall));
  
 
 
  // EXECUTION PHASE OF PIPELINE
  
  
  wire [exec_control_width-1:0] exec_control_exec_phase;
  wire [mem_control_width-1:0] mem_control_exec_phase;
  wire [wb_control_width-1:0] wb_control_exec_phase; 
  wire [31:0] rs1_exec,rs2_exec,rs3_exec,rs4_exec;
  wire [3:0] wb_add_exec,base_reg_exec;
  wire [11:0] imm1,imm2;
  
  id_alu_pipeline_reg id_exe_pipe_reg1(.clock(mod_clock),.exec_control_in(exec_control_id_phase),
  .mem_control_in(mem_control_id_phase),.wb_control_in(wb_control_id_phase),.rs1_in(rs1_after_mux),.rs2_in(out2_file),
  .rs3_in(out3_file),.rs4_in(rs4_after_mux),.wb_add_in(rs4_add),.base_reg_add_in(rs1_add),.imm_12bit_upper_in(inst[23:12])
  ,.imm_12bit_lower_in(inst[11:0]),.exec_control(exec_control_exec_phase),.mem_control(mem_control_exec_phase),
  .wb_control(wb_control_exec_phase),.rs1(rs1_exec),.rs2(rs2_exec),.rs3(rs3_exec),
  .rs4(rs4_exec),.wb_add(wb_add_exec),.base_reg_add(base_reg_exec),.imm_12bit_upper(imm1),.imm_12bit_lower(imm2));
  
  //EXEC CONTROLS exec_control={9-->shft_en,8-->imm_reg,7:4-->alu_ctrl,3-->update_flags,
  //                            2-->carry_update,1:0-->operand2_src_mux4}
  
  wire [31:0] shifted_operand;
  wire carry_frm_flag,carry_out_shifted,overflow_frm_flag,negative_frm_flag,zero_frm_flag;
  wire carry_to_flag,zero_to_flag,overflow_to_flag,negative_to_flag;
  
  shifter shift1(.enable(exec_control_exec_phase[9]),.in_data(rs2_exec),.in_data_imm(imm2[7:0]),
  .imm_or_reg(exec_control_exec_phase[8]),.shift_control(imm2[6:4]),.shift_amt_imm(imm2[11:7]),
  .shift_amt_reg(rs3_exec),.rotation_code(imm2[11:8]),.carry_in(carry_frm_flag),.carry_out(carry_out_shifted),
  .out_data(shifted_operand));
  
  wire [31:0] offset_after_sign_extension,alu_src2,alu_result;

  sign_extender_26x32 sign_extender1({imm1,imm2,2'b00},offset_after_sign_extension);
  
  mux_4x1_32bit operand2_src_mux4_unit(shifted_operand,rs2_exec,{{20{1'b0}},imm2},offset_after_sign_extension,exec_control_exec_phase[1:0],alu_src2);
  
  flag_register fl_reg1(.carry_update(exec_control_exec_phase[2]),.update_flags(exec_control_exec_phase[3]),
  .negative_in(negative_to_flag),.zero_in(zero_to_flag),.carry_in(carry_to_flag),.overflow_in(overflow_to_flag),
  .negative_out(negative_frm_flag),.zero_out(zero_frm_flag),.carry_out(carry_frm_flag),.overflow_out(overflow_frm_flag));
  
  arithematic_logic_unit alu_main1(.operand1(rs1_exec),.operand2(alu_src2),.carry_in(carry_frm_flag),
  .overflow_in(overflow_frm_flag),.alu_control(exec_control_exec_phase[7:4]),.alu_out(alu_result),
  .zero_flag(zero_to_flag),.carry_flag(carry_to_flag),.negative_flag(negative_to_flag),.overflow_flag(overflow_to_flag));
  
  
  // MEM PHASE OF PIPELINE STARTS
  
  wire [mem_control_width-1:0] mem_control_mem;
  wire [wb_control_width-1:0] wb_control_mem;
  wire [31:0] alu_result_mem,base_reg_content_mem,mem_data_write_out_mem;
  wire [3:0] wb_add_mem,base_reg_add_mem; 
  
  
  alu_mem_pipeline_reg exe_mem_pipe_reg1(.alu_result(alu_result),.base_reg_content_load_post(rs1_exec),
  .mem_data_write(rs4_exec),.wb_address(wb_add_exec),.base_register_address(base_reg_exec),
  .mem_control(mem_control_exec_phase),.wb_control(wb_control_exec_phase),.clock(clock),.alu_result_out(alu_result_mem),
  .base_reg_content_out(base_reg_content_mem),.mem_data_write_out(mem_data_write_out_mem),.wb_address_out(wb_add_mem),
  .base_register_address_out(base_reg_add_mem),.mem_control_out(mem_control_mem),.wb_control_out(wb_control_mem));
  
  wire [31:0] data_address,mem_out;
  
  //mem_control={6-->mem_rd,5-->mem_wr,4-->word_or_byte,3--->mem_address_select_mux5,
  //              2-->wb_content_select_mux6,1-->base_reg_update_content_sel_mux7,0-->swp}
  
  mux_2x1_32bit mem_address_select_mux5_unit(.in_data1(alu_result_mem),.in_data2(base_reg_content_mem),
                                            .select(mem_control_mem[3]),.out_data(data_address));
                                            
  data_mem data_mem_unit1(.mem_read(mem_control_mem[6]),.mem_write(mem_control_mem[5]),.word_or_byte(mem_control_mem[4]),
  .address(data_address),.write_data(mem_data_write_out_mem),.out_data(mem_out));
  
  wire [31:0] wb_content_mem,base_reg_update_mem;
  
  mux_2x1_32bit wb_content_select_mux6_unit(.in_data1(mem_out),.in_data2(alu_result_mem),.select(mem_control_mem[2]),
  .out_data(wb_content_mem));
  mux_2x1_32bit base_reg_update_content_sel_mux7_unit(.in_data1(base_reg_content_mem),.in_data2(alu_result_mem),
  .select(mem_control_mem[1]),.out_data(base_reg_update_mem));
  
    
  
  
  // WRITE BACK PHASE OF PIPELINE
  
  
  wb_pipeline_reg wb_pipe_reg1(.clock(clock),.wb_control_in(wb_control_mem),.wb_content_in(wb_content_mem),
  .base_register_update_content_in(base_reg_update_mem),.wb_add_in(wb_add_mem),
  .reg_update_address_in(base_reg_add_mem),.wb_control(wb_control_wb),.wb_content(wb_data_wb),
  .base_register_update_content(reg_updt_data_wb),
  .wb_add(wb_add_wb),.reg_update_address(reg_updt_add_wb));
  
  
  initial
  clock=0;
  
  always
  #5clock=~clock;
  
  
endmodule                                             