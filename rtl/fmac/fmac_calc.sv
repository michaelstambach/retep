`include "common_cells/registers.svh"

module fmac_calc (
    // clock
    input logic clk_i,
    // resetter
    input logic rst_ni,

    input logic [31:0] data_i,

    input logic sum_i,
    input logic ready_i,
    input logic clear_i,

    output logic [31:0] data_o
);

logic [31:0] data_d, data_q;
logic [31:0] data_to_sum, data_mul_sum, data_mul, data_new;

`FF(data_q, data_d, '0);

// multiplication
assign data_mul = data_i[15:0] * data_i[31:16];

// sum or multiplication
assign data_mul_sum = sum_i ? data_i[31:0] : data_mul;

// data ready to be accumulated
assign data_to_sum = ready_i ? data_mul_sum : 32'b0;

//accumulation
assign data_new = data_q + data_to_sum;

// clear data
assign data_d = clear_i ? 32'b0 : data_new;

// output data
assign data_o = data_q;


endmodule