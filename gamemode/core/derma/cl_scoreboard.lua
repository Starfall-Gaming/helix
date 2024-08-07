local rowPaintFunctions = {
    function(width, height)
    end,

    function(width, height)
        surface.SetDrawColor(30, 30, 30, 25)
        surface.DrawRect(0, 0, width, height)
    end
}

local PANEL = {}

AccessorFunc(PANEL, "model", "Model", FORCE_STRING)
AccessorFunc(PANEL, "bHidden", "Hidden", FORCE_BOOL)

function PANEL:Init()
    self:SetSize(64, 64)
    self.bodygroups = "000000000"
end

function PANEL:SetModel(model, skin, bodygroups)
    model = model:gsub("\\", "/")

    if (isstring(bodygroups)) then
        if (bodygroups:len() == 9) then
            for i = 1, bodygroups:len() do
                self:SetBodygroup(i, tonumber(bodygroups[i]) or 0)
            end
        else
            self.bodygroups = "000000000"
        end
    end

    self.model = model
    self.skin = skin
    self.path = "materials/spawnicons/" ..
        model:sub(1, #model - 4) .. -- remove extension
        ((isnumber(skin) and skin > 0) and ("_skin" .. tostring(skin)) or "") .. -- skin number
        (self.bodygroups != "000000000" and ("_" .. self.bodygroups) or "") .. -- bodygroups
        ".png"

    local material = Material(self.path, "smooth")

    if (material:IsError()) then
        self.id = "ixScoreboardIcon" .. self.path
        self.renderer = self:Add("ModelImage")
        self.renderer:SetVisible(false)
        self.renderer:SetModel(model, skin, self.bodygroups)
        self.renderer:RebuildSpawnIcon()

        hook.Add("SpawniconGenerated", self.id, function(lastModel, filePath, modelsLeft)
            filePath = filePath:gsub("\\", "/"):lower()

            if (filePath == self.path) then
                hook.Remove("SpawniconGenerated", self.id)

                self.material = Material(filePath, "smooth")
                self.renderer:Remove()
            end
        end)
    else
        self.material = material
    end
end

function PANEL:SetBodygroup(k, v)
    if (k < 0 or k > 8 or v < 0 or v > 9) then
        return
    end

    self.bodygroups = self.bodygroups:SetChar(k + 1, v)
end

function PANEL:GetModel()
    return self.model or "models/error.mdl"
end

function PANEL:Paint(width, height)
    if (self.bHidden) then
        return
    end

    if (self.material) then
        surface.SetMaterial(self.material)
        surface.SetDrawColor(255, 255, 255, 255)
        surface.DrawTexturedRect(0, 0, width, height)
    end
end

vgui.Register("ixScoreboardModelIcon", PANEL, "Panel")

local PANEL = {}

function PANEL:Init()
    self:Dock(TOP)
    self:SetTall(36)
    self:DockPadding(8, 8, 8, 8)
    self:DockMargin(0, 0, 0, 8)

    self:SetMouseInputEnabled(true)

    self.icon = self:Add("ixScoreboardModelIcon")
    self.icon:SetWide(64)
    self.icon:Dock(LEFT)
    self.icon:DockMargin(0, 0, 8, 0)

	self.name = self:Add("DLabel")
	self.name:DockMargin(4, 4, 0, 0)
	self.name:Dock(TOP)
	self.name:SetTextColor(color_white)
	self.name:SetFont("ixGenericFont")

	self.description = self:Add("DLabel")
	self.description:DockMargin(5, 0, 0, 0)
	self.description:Dock(TOP)
	self.description:SetTextColor(color_white)
	self.description:SetFont("ixSmallFont")

	self.paintFunction = rowPaintFunctions[1]
	self.nextThink = CurTime() + 1
end

function PANEL:Update()
	local client = self.player
	local model = client:GetModel()
	local skin = client:GetSkin()
    local rank = ""
    if playerRanks[client:SteamID64()] then rank = playerRanks[client:SteamID64()].rank .. " " end
	local name = rank .. client:GetName()
	local description = hook.Run("GetCharacterDescription", client) or
		(client:GetCharacter() and client:GetCharacter():GetDescription()) or ""

	local localCharacter = LocalPlayer():GetCharacter()
	local character = IsValid(self.player) and self.player:GetCharacter()


	-- no easy way to check bodygroups so we'll just set them anyway
	for _, v in pairs(client:GetBodyGroups()) do
		self.icon:SetBodygroup(v.id, client:GetBodygroup(v.id))
	end

	if (self.icon:GetModel() != model or self.icon:GetSkin() != skin) then
		self.icon:SetModel(model, skin)
		self.icon:SetTooltip(nil)
	end

	if (self.name:GetText() != name) then
		self.name:SetText(name)
		self.name:SizeToContents()
	end

	if (self.description:GetText() != description) then
		self.description:SetText(description)
		self.description:SizeToContents()
	end
end

function PANEL:Think()
	if (CurTime() >= self.nextThink) then
		local client = self.player

		if (!IsValid(client) or !client:GetCharacter() or self.character != client:GetCharacter() or self.team != client:Team()) then
			self:Remove()
			self:GetParent():SizeToContents()
		end

		self.nextThink = CurTime() + 1
	end
end

function PANEL:SetPlayer(client)
	self.player = client
	self.team = client:Team()
	self.character = client:GetCharacter()

	self:Update()
end

function PANEL:Paint(width, height)
	self.paintFunction(width, height)
end

vgui.Register("ixScoreboardRow", PANEL, "EditablePanel")

-- faction grouping
PANEL = {}

AccessorFunc(PANEL, "faction", "Faction")

function PANEL:Init()
	self:DockMargin(0, 0, 0, 16)
	self:SetTall(32)

	self.nextThink = 0
end

function PANEL:AddPlayer(client, index)
	if (!IsValid(client) or !client:GetCharacter() or hook.Run("ShouldShowPlayerOnScoreboard", client) == false) then
		return false
	end

	local id = index % 2 == 0 and 1 or 2
	local panel = self:Add("ixScoreboardRow")
	panel:SetPlayer(client)
	panel:Dock(TOP)
	panel:SetZPos(2)
	panel:SetBackgroundPaintFunction(rowPaintFunctions[id])

    self:SizeToContents()
end

vgui.Register("ixScoreboardPlayerRow", PANEL, "EditablePanel")

-- Include this in the scoreboard creation logic
function CreateScoreboard()
    local scoreboard = vgui.Create("DPanel")
    scoreboard:Dock(FILL)
    scoreboard:DockPadding(16, 16, 16, 16)
    
    scoreboard.Paint = function(self, width, height)
        derma.SkinHook("Paint", "Panel", self, width, height)
    end

    local playerList = scoreboard:Add("DScrollPanel")
    playerList:Dock(FILL)

    for _, client in ipairs(player.GetAll()) do
        local row = playerList:Add("ixScoreboardPlayerRow")
        row:Setup(client)
    end
end

vgui.Register("ixScoreboard", PANEL, "DScrollPanel")

hook.Add("CreateMenuButtons", "ixScoreboard", function(tabs)
	tabs["scoreboard"] = function(container)
		container:Add("ixScoreboard")
	end
end)