--[[
@author Universal Invariant
@version 0.1.0
@changelog
	+ Initial release
@description gmem Viewer.


--]]
local VSDEBUG = dofile("L:/gh/Programming/Music/Reaper/vscode-reascript-extension/debugger/LoadDebug.lua")


StateKey = "LogViewerState"

-- Note that one may need to delete ini files in 'C:\REAPER\ReaImGui' If script keeps failing for no reason.

-----------------------------------------------------------------------------------------------------------------------------------
state = {
	search = "",
	offset = 0,
	numRows = 50,
}

-- Used to force lua errors to be displayed in the console(as ImGui seems to hide them).
local rdefer = reaper.defer
reaper.defer = function(c)
	return rdefer(function() xpcall(c,
		function(err)
			reaper.ShowConsoleMsg(err .. '\n\n' .. debug.traceback())
		end)
	end)
end






package.path = reaper.ImGui_GetBuiltinPath() .. '/?.lua'
ImGui = require 'imgui' '0.9.3'
ctx = ImGui.CreateContext('gmem Viewer') -- Note that the label must be unique or it will cause strange issues with begin/end


fonts = {
	small = ImGui.CreateFont('Arial', 14),
	normal = ImGui.CreateFont('Arial', 19),
	large = ImGui.CreateFont('Arial', 26),
	hex = ImGui.CreateFont('Consolas', 14),

	smallBold = ImGui.CreateFont('Arial', 14, ImGui.FontFlags_Bold),
	normalBold = ImGui.CreateFont('Arial', 19, ImGui.FontFlags_Bold),
	largeBold = ImGui.CreateFont('Arial', 26, ImGui.FontFlags_Bold),
}

for k, v in pairs(fonts) do
	ImGui.Attach(ctx, v)
end



-- Handle project closes(doesn't work to stop errors)
endScriptCompletely = false
reaper.atexit(function ()
	endScriptCompletely = true
end)

function tochar(...)
	local t = {...}
	local s = ""
	for i = 1, #t do
		if t[i] == nil then
			t[i] = 0
		end
		local c = string.char(t[i])
		if t[i] < 32 or t[i] > 126 then
			c = "."
		end
		s = s .. c
	end
	return s
end

function isInteger(v) return type(v) == "number" and math.type and math.type(v) == "integer" or v == math.floor(v) end
function isDouble(v) return type(v) == "number" and math.type and math.type(v) == "float" end
function isString(v) return type(v) == "string" end

function numberToHex(v)
    if isInteger(v) then
        local bytes = string.pack("i8", v)
        bytes = string.reverse(bytes) -- Reverse bytes to simulate big-endian
        --bytes = string.rep("\0", 4) .. bytes -- Zero-extend to 8 bytes
        local hex = ""
        for i = 1, 8 do
            hex = hex .. string.format("%02X", string.byte(bytes, i))
        end
        return hex, bytes

    elseif isDouble(v) then
        local bytes = string.pack("d", v)
        local hex = ""
        for i = 1, 8 do
            hex = hex .. string.format("%02X", string.byte(bytes, i))
        end
        return hex, bytes
	else
		return v
    end
end


function bytesToAscii(bytes)
    local ascii = ""
    for i = 1, #bytes do
        local b = string.byte(bytes, i)
        if b >= 32 and b <= 126 then
            ascii = ascii .. string.char(b)
        else
            ascii = ascii .. "."
        end
    end
    return ascii
end



function gm(sharedMemoryName) reaper.gmem_attach(sharedMemoryName) end
function gmR(index) return reaper.gmem_read(index) or 0 end
function gmW(index, val) return reaper.gmem_write(index, val) end



-- Load state
state.gmem = reaper.GetExtState(StateKey, "gmem") or ""
state.numRows = tonumber(reaper.GetExtState(StateKey, "numRows")) or 50
gm(state.gmem)

local footer_r = nil
local footer_i = nil

--------------------------------------- MAIN -----------------------------
local function loop()
	if endScriptCompletely then return end
	local visible, open = ImGui.Begin(ctx, 'MainWindow', true)
	local retval, str



	-- Get midi items by reading the gmem buffer that contains the midi data. Note that this is not thread safe but may work 99.9% of the time.
	--getMidiEvents()


	-- Show main window
	if visible then


		-- Setup overall style
		ImGui.PushFont(ctx, fonts.normal)
		ImGui.PushStyleVar(ctx, ImGui.StyleVar_FramePadding, 5, 5)
		ImGui.PushStyleVar(ctx, ImGui.StyleVar_ItemSpacing, 5, 5)


		-- Settings/Configuration
		col = 0x93446333
		ImGui.PushStyleColor(ctx, ImGui.Col_FrameBg, col)
		ImGui.PushStyleColor(ctx, ImGui.Col_Button, col)
		ImGui.PushStyleColor(ctx, ImGui.Col_Header, col + 0x63)
		if ImGui.CollapsingHeader(ctx, 'Configuration') then
			-- Show REPL Window (very useful for debugging)
			if ImGui.Button(ctx, 'Show REPL Window') then
				dofile("C:\\REAPER\\Scripts\\ReaTeam Scripts\\Development\\cfillion_Interactive ReaScript.lua")
			end
		end
		ImGui.PopStyleColor(ctx, 3)


		ImGui.Spacing(ctx)
		ImGui.Separator(ctx)
		ImGui.Spacing(ctx)

		offsetScale = 1 -- how many items per row, this is used to calculate the address of the item in the gmem buffer

		--ImGui.PushStyleVar(ctx, ImGui.StyleVar_ItemSpacing, 35, 0)


		-- mem
		ImGui.PushItemWidth(ctx, 300)
		retval, str = ImGui.InputText(ctx, 'gmem', state.gmem, ImGui.InputTextFlags_ParseEmptyRefVal | ImGui.InputTextFlags_EscapeClearsAll | ImGui.InputTextFlags_CallbackCharFilter)
		if (retval) then
			state.gmem = str
			gm(state.gmem) -- reattach to the new gmem
			reaper.SetExtState(StateKey, "gmem", state.gmem, true) -- save to extstate
		end
		ImGui.PopItemWidth(ctx)

		ImGui.PushItemWidth(ctx, 0)
		ImGui.PushStyleVar(ctx, ImGui.StyleVar_ItemSpacing, 50, 0)
		ImGui.SameLine(ctx)
		ImGui.Text(ctx, " ")
		ImGui.PopStyleVar(ctx, 1)
		ImGui.PopItemWidth(ctx)

		ImGui.PushItemWidth(ctx, 150)
		ImGui.SameLine(ctx)
		retval, str = ImGui.InputInt(ctx, 'Num Rows', state.numRows, 1, 10)
		if retval then
			state.numRows = math.max(5, tonumber(str) or 5)
			reaper.SetExtState(StateKey, "numRows", tostring(state.numRows), true) -- save to extstate
		end
		ImGui.PopItemWidth(ctx)

		ImGui.PushItemWidth(ctx, 300)
		retval, str = ImGui.InputInt(ctx, 'Offset', state.offset, math.max(1, offsetScale), 1000)
		if retval then
			state.offset = math.min(33554432, math.max(0, tonumber(str) or 0))
		end
		ImGui.PopItemWidth(ctx)



		-- Search
		retval, str = ImGui.InputText(ctx, 'Search', state.search, ImGui.InputTextFlags_ParseEmptyRefVal | ImGui.InputTextFlags_EscapeClearsAll | ImGui.InputTextFlags_CallbackCharFilter)
		if (retval) then
			state.search = str
		end

			ImGui.PushStyleVar(ctx, ImGui.StyleVar_ItemSpacing, 18, 0)
			ImGui.Separator(ctx)
			-- footer
			local s = ""
			local ln = ""
			ImGui.Spacing(ctx)
			ImGui.BeginGroup(ctx)
			ImGui.PushFont(ctx, fonts.small)
			if footer_i ~= nil then
				s = string.format("Index: %d", footer_i or 0)
				if isInteger(footer_r) then
					s = s..string.format(", Integer: %d",  footer_r)
					if footer_r > 32 and footer_r < 127 then
						s = s..string.format(", ASCII: %s", tochar(footer_r))
					end
				elseif isDouble(footer_r) then
					s = s..string.format(", Double: %f",  footer_r)
				end
			end
			ImGui.Text(ctx,	s)

			ImGui.PopFont(ctx)
			ImGui.EndGroup(ctx)
			ImGui.PopStyleVar(ctx)

		footer_r = nil
		footer_i = nil

		-- Memory values
		if state.gmem ~= "" then
			ImGui.Spacing(ctx)
			ImGui.NewLine(ctx)
			ImGui.Spacing(ctx)

			local w = ImGui.CalcTextSize(ctx, string.format("0000000000000000", i), nil, nil, true)


			ImGui.PushFont(ctx, fonts.hex)
			ImGui.PushStyleColor(ctx, ImGui.Col_FrameBg, 0)
			ImGui.PushStyleVar(ctx, ImGui.StyleVar_FramePadding, 0, 0)
			ImGui.PushStyleVar(ctx, ImGui.StyleVar_ItemSpacing, 2, 0)
			ImGui.PushStyleVar(ctx, ImGui.StyleVar_ItemInnerSpacing, 0, 0)


			for j = 0, state.numRows-1 do
				ImGui.PushItemWidth(ctx, w+10)
				for i = 0, 7 do
					ImGui.SameLine(ctx)
					local r = gmR(i + j*8 + state.offset)
					local h = numberToHex(r)
					---local r, b = ImGui.Text(ctx, h)
					if ImGui.Selectable(ctx, h, false, ImGui.SelectableFlags_AllowDoubleClick, w) then

						--reaper.ShowConsoleMsg((ImGui.IsKeyDown(ctx, ImGui.Mod_Ctrl)  and 'CTRL ' or '')..(ImGui.IsKeyDown(ctx, ImGui.Mod_Shift) and 'SHIFT '  or '')..(ImGui.IsKeyDown(ctx, ImGui.Mod_Alt)   and 'ALT '    or '')..(ImGui.IsKeyDown(ctx, ImGui.Mod_Super) and 'SUPER '  or ''))
						if ImGui.IsMouseDoubleClicked(ctx, 0) then
							-- If an integer and ctrl is pressed then jumps to the offset in the gmem buffer using hte value
							if isInteger(r) then
								--if ImGui.IsKeyDown(ctx, ImGui.Mod_Ctrl) then
									state.offset = r
								--end
							else

							end
						else
							if isInteger(r) then

							else

							end
						end
					end
					if ImGui.IsItemHovered(ctx) then
						footer_r = r
						footer_i = i + j*8 + state.offset
					end

					-- Displays a tooltip with the value of the item when hovered
					if ImGui.IsKeyDown(ctx, ImGui.Mod_Shift) then
						if ImGui.BeginItemTooltip(ctx) then
							ImGui.PushTextWrapPos(ctx, ImGui.GetFontSize(ctx) * 35.0)
							ImGui.Text(ctx, string.format("Index: %d",  i + j*8 + state.offset))
							if isInteger(r) then
								ImGui.Text(ctx, string.format("As Integer: %d",  r))
								if r > 32 and r < 127 then
									ImGui.Text(ctx, string.format("As ASCII: %s", tochar(r)))
								end
							elseif isDouble(r) then
								ImGui.Text(ctx, string.format("As Double: %f",  r))
							else
								ImGui.Text(ctx, "Not a number")
							end
							ImGui.PopTextWrapPos(ctx)
							ImGui.EndTooltip(ctx)
						end
					end

				end




				ImGui.PushItemWidth(ctx, 0)
				ImGui.PushStyleVar(ctx, ImGui.StyleVar_ItemSpacing, 50, 0)
				ImGui.SameLine(ctx)
				ImGui.Text(ctx, " ")


				local s = ""
				for i = 0, 7 do
					local r = gmR(i + j*8 + state.offset)
					local h,b = numberToHex(r)
					local ascii = bytesToAscii(b)
					s = s .. ascii
				end


				ImGui.PushStyleVar(ctx, ImGui.StyleVar_ItemSpacing, 0, 0)
				ImGui.SameLine(ctx)
				local r, b = ImGui.Text(ctx, s)
				if r then

				end
				ImGui.PopStyleVar(ctx, 2)


				ImGui.PopItemWidth(ctx)

				ImGui.NewLine(ctx)
			end
			ImGui.PopStyleVar(ctx, 3)
			ImGui.PopStyleColor(ctx, 1)
			ImGui.PopFont(ctx)
		end



		-- visibility footer
		ImGui.PopStyleVar(ctx, 2)
		ImGui.PopFont(ctx)

		ImGui.End(ctx)
	end -- if visible


	if open then
		reaper.defer(loop)
	else
		-- exit script

	end


end

reaper.defer(loop)


