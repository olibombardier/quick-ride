data:extend({
	{
		type = "double-setting",
		name = "qr-double-tap-delay",
		setting_type = "runtime-per-user",
		minimum_value = 0.1,
		maximum_value = 1.0,
		default_value = 0.25,
	},
	{
		type = "bool-setting",
		name = "qr-show-used-fuel",
		setting_type = "runtime-per-user",
		default_value = true,
	},
	{
		type = "bool-setting",
		name = "qr-handle-trains",
		setting_type = "runtime-per-user",
		default_value = true,
		order = "train-a",
	},
	{
		type = "bool-setting",
		name = "qr-correct-train-direction",
		setting_type = "runtime-per-user",
		default_value = true,
		order = "train-b"
	},
	{
		type = "bool-setting",
		name = "qr-opens-train-menu",
		setting_type = "runtime-per-user",
		default_value = false,
		order = "train-c",
	},
	{
		type = "string-setting",
		name = "qr-inventory-full-action",
		setting_type = "runtime-per-user",
		default_value = "stay-in",
		allowed_values = {
			"stay-in",
			"get-out",
		},
	},
	{
		type = "bool-setting",
		name = "qr-ignore-unhandled-on-exit",
		setting_type = "runtime-per-user",
		default_value = true
	}
})
