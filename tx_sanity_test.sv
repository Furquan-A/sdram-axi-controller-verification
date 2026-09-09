import uvm_pkg::*;
`include "uvm_macros.svh"

`include "axi_agent/axi_transaction.sv"

module tx_sanity_test;

    initial begin

        axi_transaction tr;

        $display("---------------------------------------------------------");
        $display(" TX   OP      BURST    ADDR        LEN   BEATS");
        $display("---------------------------------------------------------");

        for (int i = 0; i < 20; i++) begin

            tr = axi_transaction::type_id::create(
                    $sformatf("tr_%0d", i)
                 );

            // Force only WRAP transactions for this sanity test
            if (!tr.randomize() with {
                burst == axi_transaction::WRAP;
            })
                `uvm_fatal(
                    "RAND_FAIL",
                    $sformatf("Randomization failed for TX %0d", i)
                )

            $display(
                "%2d   %-5s   %-5s   0x%08h   %2d    %2d",
                i,
                tr.op.name(),
                tr.burst.name(),
                tr.addr,
                tr.length,
                tr.length + 1
            );

            // Sanity check WRAP LEN encoding
            if (!(tr.length inside {1, 3, 7, 15}))
                `uvm_error(
                    "WRAP_LEN",
                    $sformatf(
                        "Illegal WRAP LEN generated: %0d",
                        tr.length
                    )
                );

        end

        $display("---------------------------------------------------------");

        $finish;

    end

endmodule