
// free flip flop download
`include "common_cells/registers.svh"

module user_test #(
    parameter obi_pkg::obi_cfg_t    SbrObiCfg    = obi_pkg::ObiDefaultConfig,
    parameter type                  sbr_obi_req_t = logic,
    parameter type                  sbr_obi_rsp_t = logic,
    parameter obi_pkg::obi_cfg_t    MgrObiCfg    = obi_pkg::ObiDefaultConfig,
    parameter type                  mgr_obi_req_t = logic,
    parameter type                  mgr_obi_rsp_t = logic
) (
    // uhr
    input logic clk_i,
    // zurücksetzer
    input logic rst_ni,

    // obi zeugs
    input   sbr_obi_req_t obi_sbr_req_i,
    output  sbr_obi_rsp_t obi_sbr_rsp_o,
    output   mgr_obi_req_t obi_mgr_req_o,
    input  mgr_obi_rsp_t obi_mgr_rsp_i,

    // störsender
    output  logic interrupt_o
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

// obi master request data
logic mgr_req_d, mgr_req_q;
logic [MgrObiCfg.AddrWidth-1:0] mgr_addr_d, mgr_addr_q;
//logic mgr_we_d, mgr_we_q;
//logic [MgrObiCfg.DataWidth/8-1:0] mgr_be_d, mgr_be_q;
//logic [MgrObiCfg.Datawidth-1:0] mgr_wdata_d, mgr_wdata_q;

// obi master response data
logic mgr_gnt_d, mgr_gnt_q;
logic mgr_rvalid_d, mgr_rvalid_q;
logic [MgrObiCfg.DataWidth-1:0] mgr_rdata_d, mgr_rdata_q;
logic mgr_err_d, mgr_err_q;

// internal registers
logic [SbrObiCfg.DataWidth-1:0] count_d, count_q;
//logic [31:0] dma_addr_d, dma_addr_q;
logic [31:0] dma_data_d, dma_data_q;
logic interrupt_d, interrupt_q;

// flopflips
`FF(sbr_req_q, sbr_req_d, '0);
`FF(sbr_we_q, sbr_we_d, '0);
`FF(sbr_addr_q, sbr_addr_d, '0);
`FF(sbr_id_q, sbr_id_d, '0);
`FF(sbr_wdata_q, sbr_wdata_d, '0);

`FF(mgr_req_q, mgr_req_d, '0);
`FF(mgr_addr_q, mgr_addr_d, '0);
`FF(mgr_gnt_q, mgr_gnt_d, '0);
`FF(mgr_rvalid_q, mgr_rvalid_d, '0);
`FF(mgr_rdata_q, mgr_rdata_d, '0);
`FF(mgr_err_q, mgr_err_d, '0);

`FF(count_q, count_d, '0);
`FF(interrupt_q, interrupt_d, '0);
`FF(dma_data_q, dma_data_d, '0);

// obi subordinate request wiring
assign sbr_req_d = obi_sbr_req_i.req;
assign sbr_we_d = obi_sbr_req_i.a.we;
assign sbr_addr_d = obi_sbr_req_i.a.addr;
assign sbr_id_d = obi_sbr_req_i.a.aid;
assign sbr_wdata_d = obi_sbr_req_i.a.wdata;

assign interrupt_o = interrupt_q;

// obi manager response wiring
assign mgr_gnt_d = obi_mgr_rsp_i.gnt;
assign mgr_rvalid_d = obi_mgr_rsp_i.rvalid;
assign mgr_rdata_d = obi_mgr_rsp_i.r.rdata;
assign mgr_err_d = obi_mgr_rsp_i.r.err;

logic [3:0] word_addr;
always_comb begin
    sbr_rsp_data = '0;
    sbr_rsp_err = '0;
    word_addr = sbr_addr_q[5:2];
    count_d = count_q;
    interrupt_d = '0;
    dma_data_d = dma_data_q;

    mgr_req_d = mgr_req_q;
    mgr_addr_d = mgr_addr_q;

    // address ttransfer accepted
    if (mgr_gnt_q) begin
        mgr_req_d = '0;
    end

    // incoming request
    if (sbr_req_q) begin
        case(word_addr)
        4'h0: begin
            if (sbr_we_q) begin
                count_d = sbr_wdata_q;
            end else begin
                sbr_rsp_data = count_q;
            end
        end
        4'h1: begin
            if (sbr_we_q) begin
                // start a dma request
                mgr_addr_d = sbr_wdata_q;
                mgr_req_d = 1'b1;
            end else begin
                sbr_rsp_data = 32'hffffffff;
                sbr_rsp_err = '1;
            end
        end
        4'h2: begin
            // dma value register
            if (sbr_we_q) begin
                dma_data_d = sbr_wdata_q;
            end else begin
                sbr_rsp_data = dma_data_q;
            end
        end
        default: begin
            sbr_rsp_data = 32'hffffffff;
            sbr_rsp_err = '1;
        end
        endcase
    end

    // response arrived
    if (mgr_rvalid_q) begin
        dma_data_d = mgr_rdata_q;
    end

    // handle sending interrupt
    if (count_q != '0) begin
        count_d = count_q - 1'b1;
        // trigger interrupt for one cycle
        if (count_q < 32'd16) begin
            interrupt_d = 1'b1;
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

// manager request wiring
assign obi_mgr_req_o.req = mgr_req_q;
assign obi_mgr_req_o.a.addr = mgr_addr_q;
assign obi_mgr_req_o.a.we = '0;
assign obi_mgr_req_o.a.be = 4'b1111;
assign obi_mgr_req_o.a.wdata = '0;
assign obi_mgr_req_o.a.aid = '0;
assign obi_mgr_req_o.a.a_optional = '0;

endmodule

