
// flip flap flubidbap
`include "common_cells/registers.svh"

module fmac_pkg #(
    parameter obi_pkg::obi_cfg_t    SbrObiCfg    = obi_pkg::ObiDefaultConfig,
    parameter type                  sbr_obi_req_t = logic,
    parameter type                  sbr_obi_rsp_t = logic,
    parameter obi_pkg::obi_cfg_t    MgrObiCfg    = obi_pkg::ObiDefaultConfig,
    parameter type                  mgr_obi_req_t = logic,
    parameter type                  mgr_obi_rsp_t = logic
) (
    // clock
    input logic clk_i,
    // resetter
    input logic rst_ni,

    // obi sbr
    input   sbr_obi_req_t obi_sbr_req_i,
    output  sbr_obi_rsp_t obi_sbr_rsp_o,
    // obi mgr
    output  mgr_obi_req_t obi_mgr_req_o,
    input   mgr_obi_rsp_t obi_mgr_rsp_i,

    // interrupter
    output logic interrupt_o
);

// Enums
// =====

typedef enum logic {
    Stop = 1'b0,
    Run = 1'b1
} state_t;

// Wire definitions
// ===========================

// OBI subordinate request (incoming)
logic sbr_req_d, sbr_req_q;
logic sbr_we_d, sbr_we_q;
logic [SbrObiCfg.AddrWidth-1:0] sbr_addr_d, sbr_addr_q;
logic [SbrObiCfg.IdWidth-1:0] sbr_id_d, sbr_id_q;
logic [SbrObiCfg.DataWidth-1:0] sbr_wdata_d, sbr_wdata_q;

// OBI subordinate response (outgoing)
logic [SbrObiCfg.DataWidth-1:0] sbr_rsp_data;
logic sbr_rsp_err;

// OBI manager request (outgoing)
// note that not all signals are used, OBI mgr is read only
logic mgr_req_d, mgr_req_q;
logic [MgrObiCfg.AddrWidth-1:0] mgr_addr;
//logic mgr_we_d, mgr_we_q;
//logic [MgrObiCfg.DataWidth/8-1:0] mgr_be_d, mgr_be_q;
//logic [MgrObiCfg.Datawidth-1:0] mgr_wdata_d, mgr_wdata_q;

// OBI manager response (incoming)
logic mgr_gnt;
logic mgr_rvalid;
logic [MgrObiCfg.DataWidth-1:0] mgr_rdata;
logic mgr_err;

// writable control registers
state_t state_d, state_q;
state_t state_req; // external request to change state
logic [31:0] src_a_d, src_a_q;
logic [31:0] src_b_d, src_b_q;
logic [31:0] len_d, len_q;

// output data
logic [31:0] calc_out;

// interrupt
logic interrupt_d, interrupt_q;

// current index into the input data
logic [31:0] index_d, index_q;

// circular intermediate data buffer and r/w pointers
logic [127:0] buf_data_d, buf_data_q;
logic [2:0] buf_ri_d, buf_ri_q;
logic [2:0] buf_wi_d, buf_wi_q;
logic buf_w_src_d, buf_w_src_q;

// signals to fmac_calc
logic [31:0] calc_data;
logic calc_sum;
logic calc_ready_d, calc_ready_q;
logic calc_clear;


// Flip-Flops
// ==========
`FF(sbr_req_q, sbr_req_d, '0);
`FF(sbr_we_q, sbr_we_d, '0);
`FF(sbr_addr_q, sbr_addr_d, '0);
`FF(sbr_id_q, sbr_id_d, '0);
`FF(sbr_wdata_q, sbr_wdata_d, '0);

`FF(mgr_req_q, mgr_req_d, '0);

`FF(state_q, state_d, Stop);
`FF(src_a_q, src_a_d, '0);
`FF(src_b_q, src_b_d, '0);
`FF(len_q, len_d, '0);

`FF(interrupt_q, interrupt_d, '0);

`FF(index_q, index_d, '0);

`FF(buf_data_q, buf_data_d, '0);
`FF(buf_ri_q, buf_ri_d, '0);
`FF(buf_wi_q, buf_wi_d, '0);
`FF(buf_w_src_q, buf_w_src_d, '0);

`FF(calc_ready_q, calc_ready_d, '0);


// Incoming data wiring
// ====================

// OBI subordinate request
assign sbr_req_d = obi_sbr_req_i.req;
assign sbr_we_d = obi_sbr_req_i.a.we;
assign sbr_addr_d = obi_sbr_req_i.a.addr;
assign sbr_id_d = obi_sbr_req_i.a.aid;
assign sbr_wdata_d = obi_sbr_req_i.a.wdata;

// OBI manager response
assign mgr_gnt = obi_mgr_rsp_i.gnt;
assign mgr_rvalid = obi_mgr_rsp_i.rvalid;
assign mgr_rdata = obi_mgr_rsp_i.r.rdata;
assign mgr_err = obi_mgr_rsp_i.r.err;

// Internal wiring / small logic
// =============================

// fmac_calc input wiring
// pass the data to the calc module according to the current read index
assign calc_data = buf_data_q[{buf_ri_q[1:0], 5'b0}+:32];
assign calc_sum = (src_b_q == 32'b0);

// dma read address
// this directly depends on the current index
assign mgr_addr = calc_sum ? src_a_q + (index_q<<2) :
                    ( index_q[0] ? src_b_q + (index_q<<1) : src_a_q + (index_q<<1) );


// Logic
// =====

// main state machine
always_comb begin
    state_d = state_q;
    index_d = index_q;

    // obi manager
    mgr_req_d = mgr_req_q;

    case (state_q)
        Run: begin
            // check for accepted address transfer on the obi manager
            if (mgr_gnt) begin
                // prepare for next request
                if (index_q < len_q) begin
                    index_d = index_q + 32'b1;
                    mgr_req_d = '1;
                end else begin
                    // done
                    mgr_req_d = '0;
                end
            end


            // conversion complete
            // index at end, buffer processed and not waiting for other half of data
            if (index_q == len_q && (buf_wi_q - buf_ri_q) == 32'b1 && ~buf_w_src_q) begin
                // todo: send interrupt
                state_d = Stop;
            end
        end
        default: begin
            if (state_req == Run) begin
                // todo: reset stuff here + send first dma req?
                index_d = '0;
                mgr_req_d = '1;
                state_d = Run;
            end else begin
                // ensure no dma transactions are triggered when stopped
                mgr_req_d = '0;
            end
        end
    endcase

end

// OBI subordinate
logic [3:0] word_addr;
always_comb begin
    // addressing
    sbr_rsp_data = '0;
    sbr_rsp_err = '0;
    word_addr = sbr_addr_q[5:2];

    // by default, retain control register values
    state_req = state_q;
    src_a_d = src_a_q;
    src_b_d = src_b_q;
    len_d   = len_q;

    // incoming request
    if (sbr_req_q) begin
        case(word_addr)
        // 0x00: State
        4'h0: begin
            if (sbr_we_q) begin
                if (sbr_wdata_q != '0) begin
                    // any value but zero sets state to Run
                    state_req = Run;
                end else begin
                    state_req = Stop;
                end
            end else begin
                sbr_rsp_data = state_q;
            end
        end
        // 0x04: DMA data source A
        4'h1: begin
            if (sbr_we_q) begin
                src_a_d = sbr_wdata_q;
            end else begin
                sbr_rsp_data = src_a_q;
            end
        end
        // 0x08: DMA data source B
        4'h2: begin
            if (sbr_we_q) begin
                src_b_d = sbr_wdata_q;
            end else begin
                sbr_rsp_data = src_b_q;
            end
        end
        // 0x0C: DMA data length
        4'h3: begin
            // internally we store len-1, easier to check boundaries
            if (sbr_we_q) begin
                len_d = sbr_wdata_q - 32'b1;
            end else begin
                sbr_rsp_data = len_q + 32'b1;
            end
        end
        // 0x10: Output data
        4'h4: begin
            // read only!
            if (sbr_we_q) begin
                sbr_rsp_err = 32'b1;
            end else begin
                sbr_rsp_data = calc_out;
            end
        end
        default: begin
            sbr_rsp_data = 32'hffffffff;
            sbr_rsp_err = '1;
        end
        endcase
    end
end

// OBI manager
// this only handles the response, request is sent from the main state machine
logic [6:0] buf_wi_bits; // helper signal
always_comb begin
    buf_wi_d = buf_wi_q;
    buf_w_src_d = buf_w_src_q; // 0 = read from src a, 1 = src b
    buf_data_d = buf_data_q;

    buf_wi_bits = {buf_wi_q[1:0], 5'b0};

    if (mgr_rvalid) begin
        if (calc_sum) begin
            buf_data_d[buf_wi_bits+:32] = mgr_rdata;
            buf_wi_d = buf_wi_q + 3'b1;
        end else begin
            if (~buf_w_src_q) begin
                buf_data_d[buf_wi_bits+:16] = mgr_rdata[15:0];
                buf_data_d[buf_wi_bits+7'd32+:16] = mgr_rdata[31:16];
            end else begin
                buf_data_d[buf_wi_bits+7'd16+:16] = mgr_rdata[15:0];
                buf_data_d[buf_wi_bits+7'd48+:16] = mgr_rdata[31:16];
                // only advance write index once both halves appeared
                // but advance it by 2
                buf_wi_d = buf_wi_q + 3'b10;
            end
            buf_w_src_d = ~buf_w_src_q;
        end
    end

    // when stopped, reset write index
    if (state_q == Stop) begin
        buf_wi_d = 3'b000;
        buf_w_src_d = '0;
    end
end


// Read index and ready signal logic
always_comb begin

    buf_ri_d = buf_ri_q;
    calc_ready_d = '0;

    if ((buf_ri_q + 3'b1) < buf_wi_q) begin
        buf_ri_d = buf_ri_q + 3'b1;
        calc_ready_d = '1;
    end

    if (state_q == Stop) begin
        // in the stopped state reset to the highest possible value
        // if we would start the read index at 0 we miss the first item
        buf_ri_d = 3'b111;
    end
end

// Outgoing data wiring
// ====================

// OBI subordinate response
assign obi_sbr_rsp_o.gnt = obi_sbr_req_i.req;
assign obi_sbr_rsp_o.rvalid = sbr_req_q;
assign obi_sbr_rsp_o.r.rdata = sbr_rsp_data;
assign obi_sbr_rsp_o.r.rid = sbr_id_q;
assign obi_sbr_rsp_o.r.err = sbr_rsp_err;
assign obi_sbr_rsp_o.r.r_optional = '0;

// OBI manager request
assign obi_mgr_req_o.req = mgr_req_q;
assign obi_mgr_req_o.a.addr = mgr_addr;
assign obi_mgr_req_o.a.we = '0; // read only
assign obi_mgr_req_o.a.be = 4'b1111;
assign obi_mgr_req_o.a.wdata = '0;
assign obi_mgr_req_o.a.aid = '0;
assign obi_mgr_req_o.a.a_optional = '0;


endmodule

