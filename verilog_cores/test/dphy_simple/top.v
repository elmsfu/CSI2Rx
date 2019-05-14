module top(input dphy_clk,
	   output dbg_dphy_clk);

   SB_IO #(
	   .PIN_TYPE(6'b000001),
	   .IO_STANDARD("SB_LVDS_INPUT")
	   ) clk_iobuf (
			.PACKAGE_PIN(dphy_clk),
			.D_IN_0(dbg_dphy_clk)
			);

endmodule // top
