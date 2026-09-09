import uvm_pkg::*;
`include "uvm_macros.svh"

`include "axi_agent/axi_transaction.sv"

module tx_sanity_test;

    initial begin

        axi_transaction tr;

        // Create object using UVM factory
        tr = axi_transaction::type_id::create("tr");

        // Randomize transaction
        if (!tr.randomize())
            `uvm_fatal("RAND_FAIL", "axi_transaction randomization failed")

        // Display important randomized fields
        $display("-------------------------------------");
        $display("Operation = %s", tr.op.name());
        $display("Burst     = %s", tr.burst.name());
        $display("Address   = 0x%08h", tr.addr);
        $display("ID        = %0d", tr.id);
        $display("LEN       = %0d", tr.length);
        $display("Beats     = %0d", tr.length + 1);

        $display("w_data size = %0d", tr.w_data.size());
        $display("wstrb size  = %0d", tr.wstrb.size());

        foreach (tr.w_data[i]) begin
            $display(
                "Beat[%0d] WDATA=0x%08h WSTRB=%04b",
                i,
                tr.w_data[i],
                tr.wstrb[i]
            );
        end

        $display("-------------------------------------");

        $finish;

    end

endmodule