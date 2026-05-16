
// free flip flop download
`include "common_cells/registers.svh"

module user_test #(
    parameter obi_pkg::obi_cfg_t    ObiCfg    = obi_pkg::ObiDefaultConfig,
    parameter type                  obi_req_t = logic,
    parameter type                  obi_rsp_t = logic
) (
    // uhr
    input logic clk_i,
    // zurücksetzer
    input logic rst_ni,

    // obi zeugs
    input   obi_req_t obi_req_i,
    output  obi_rsp_t obi_rsp_o,

    // störsender
    output  logic interrupt_o
);

// obi request data
logic req_d, req_q;
logic we_d, we_q;
logic [ObiCfg.AddrWidth-1:0] addr_d, addr_q;
logic [ObiCfg.IdWidth-1:0] id_d, id_q;
logic [ObiCfg.DataWidth-1:0] wdata_d, wdata_q;

// obi response data
logic [ObiCfg.DataWidth-1:0] rsp_data;
logic rsp_err;

// internal registers
logic [ObiCfg.DataWidth-1:0] count_d, count_q;
logic interrupt_d, interrupt_q;

// flopflips
`FF(req_q, req_d, '0);
`FF(we_q, we_d, '0);
`FF(addr_q, addr_d, '0);
`FF(id_q, id_d, '0);
`FF(wdata_q, wdata_d, '0);
`FF(count_q, count_d, '0);
`FF(interrupt_q, interrupt_d, '0);

assign req_d = obi_req_i.req;
assign we_d = obi_req_i.a.we;
assign addr_d = obi_req_i.a.addr;
assign id_d = obi_req_i.a.aid;
assign wdata_d = obi_req_i.a.wdata;

assign interrupt_o = interrupt_q;

logic [3:0] word_addr;
always_comb begin
    rsp_data = '0;
    rsp_err = '0;
    word_addr = addr_q[3:0];
    count_d = count_q;
    interrupt_d = '0;

    // incoming request
    if (req_q) begin
        case(word_addr)
        4'h0: begin
            if (we_q) begin
                count_d = wdata_q;
            end else begin
                rsp_data = count_q;
            end
        end
        default: begin
            rsp_data = 32'hffffffff;
            rsp_err = '1;
        end
        endcase
    end else if (count_q != '0) begin
        count_d = count_q - 1'b1;
        // trigger interrupt for one cycle
        if (count_q < 32'd16) begin
            interrupt_d = 1'b1;
        end
    end else begin
    end
end

// response wiring
assign obi_rsp_o.gnt = obi_req_i.req;
assign obi_rsp_o.rvalid = req_q;
assign obi_rsp_o.r.rdata = rsp_data;
assign obi_rsp_o.r.rid = id_q;
assign obi_rsp_o.r.err = rsp_err;
assign obi_rsp_o.r.r_optional = '0;

endmodule

