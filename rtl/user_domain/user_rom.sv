
// free flip flop download
`include "common_cells/registers.svh"

module user_rom #(
    parameter obi_pkg::obi_cfg_t    SbrObiCfg    = obi_pkg::ObiDefaultConfig,
    parameter type                  sbr_obi_req_t = logic,
    parameter type                  sbr_obi_rsp_t = logic
) (
    // uhr
    input logic clk_i,
    // zurücksetzer
    input logic rst_ni,

    // obi zeugs
    input   sbr_obi_req_t obi_sbr_req_i,
    output  sbr_obi_rsp_t obi_sbr_rsp_o
);

// obi subordinate request data
logic sbr_req_d, sbr_req_q;
logic sbr_we_d, sbr_we_q;
logic [SbrObiCfg.AddrWidth-1:0] sbr_addr_d, sbr_addr_q;
logic [SbrObiCfg.IdWidth-1:0] sbr_id_d, sbr_id_q;
logic [SbrObiCfg.DataWidth-1:0] sbr_wdata_d, sbr_wdata_q;

// obi subordinate response data
logic [SbrObiCfg.DataWidth-1:0] sbr_rsp_data;
logic sbr_rsp_err;


// flopflips
`FF(sbr_req_q, sbr_req_d, '0);
`FF(sbr_we_q, sbr_we_d, '0);
`FF(sbr_addr_q, sbr_addr_d, '0);
`FF(sbr_id_q, sbr_id_d, '0);
`FF(sbr_wdata_q, sbr_wdata_d, '0);

// obi subordinate request wiring
assign sbr_req_d = obi_sbr_req_i.req;
assign sbr_we_d = obi_sbr_req_i.a.we;
assign sbr_addr_d = obi_sbr_req_i.a.addr;
assign sbr_id_d = obi_sbr_req_i.a.aid;
assign sbr_wdata_d = obi_sbr_req_i.a.wdata;


logic [9:0] word_addr;
always_comb begin
    sbr_rsp_data = '0;
    sbr_rsp_err = '0;
    word_addr = sbr_addr_q[11:2];

    // incoming request
    if (sbr_req_q) begin
        if (~sbr_we_q) begin
            case(word_addr)
            10'd0 : sbr_rsp_data = 32'h43726F63;
            10'd1 : sbr_rsp_data = 32'h20657874;
            10'd2 : sbr_rsp_data = 32'h656E6465;
            10'd3 : sbr_rsp_data = 32'h64206279;
            10'd4 : sbr_rsp_data = 32'h20446176;
            10'd5 : sbr_rsp_data = 32'h69642053;
            10'd6 : sbr_rsp_data = 32'h7465696E;
            10'd7 : sbr_rsp_data = 32'h61636865;
            10'd8 : sbr_rsp_data = 32'h7220616E;
            10'd9 : sbr_rsp_data = 32'h64204D69;
            10'd10: sbr_rsp_data = 32'h63686165;
            10'd11: sbr_rsp_data = 32'h6C205374;
            10'd12: sbr_rsp_data = 32'h616D6261;
            10'd13: sbr_rsp_data = 32'h63682E20;
            10'd14: sbr_rsp_data = 32'h4D79206E;
            10'd15: sbr_rsp_data = 32'h616D6520;
            10'd16: sbr_rsp_data = 32'h69732052;
            10'd17: sbr_rsp_data = 32'h65746570;
            10'd18: sbr_rsp_data = 32'h20616E64;
            10'd19: sbr_rsp_data = 32'h20492061;
            10'd20: sbr_rsp_data = 32'h6D206576;
            10'd21: sbr_rsp_data = 32'h696C2E20;
            10'd22: sbr_rsp_data = 32'h53686F75;
            10'd23: sbr_rsp_data = 32'h746F7574;
            10'd24: sbr_rsp_data = 32'h20494953;
            10'd25: sbr_rsp_data = 32'h2C204554;
            10'd26: sbr_rsp_data = 32'h485A2061;
            10'd27: sbr_rsp_data = 32'h6E642046;
            10'd28: sbr_rsp_data = 32'h72616E6B;
            10'd29: sbr_rsp_data = 32'h2E000000;
            default: sbr_rsp_data = '0;
            endcase
        end else begin
            sbr_rsp_err = 32'b1;
        end
    end

end

// subordinate response wiring
assign obi_sbr_rsp_o.gnt = obi_sbr_req_i.req;
assign obi_sbr_rsp_o.rvalid = sbr_req_q;
assign obi_sbr_rsp_o.r.rdata = sbr_rsp_data;
assign obi_sbr_rsp_o.r.rid = sbr_id_q;
assign obi_sbr_rsp_o.r.err = sbr_rsp_err;
assign obi_sbr_rsp_o.r.r_optional = '0;

endmodule

