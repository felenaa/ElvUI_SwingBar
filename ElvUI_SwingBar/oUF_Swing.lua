--[[

	Elements handled:
	 .Swing [statusbar]
	 .Swing.Text [fontstring]

	Shared:
	 - disableMelee [boolean]
	 - disableRanged [boolean]
	 - disableOoc [boolean] (Autohide on leaving Combat)

	Functions that can be overridden from within a layout:
	 - :OverrideText(elapsed)

--]]


local _, ns = ...
local oUF = oUF or ElvUF or ns.oUF
if not oUF then return end

local classMap =
{
	["DRUID"] = 5176, -- "Wrath"
	["PALADIN"] = 7328, -- "Redemption" - NOTE: Attained at level 13
	["PRIEST"] = 585, -- "Smite"
	["SHAMAN"] = 403, -- "Lightning Bolt"
	["WARRIOR"] = 34428, -- "Victory Rush" - NOTE: Attained at level 5
	["DEATHKNIGHT"] = 47541, -- "Death Coil"
	["HUNTER"] = 3044, -- "Arcane Shot"
	["MAGE"] = 44614, -- "Frostfire Bolt"
	["WARLOCK"] = 686, -- "Shadow Bolt"
	["ROGUE"] = 1752, -- "Sinister Strike"
}

local OnDurationUpdate
do
	local elapsed = 0
	local castcheck = 0
	local lastcheck = 0
	function OnDurationUpdate(self)
		
		local spell = UnitCastingInfo("player")
		
		if(spell==GetSpellInfo(47475)) then
			if castcheck == 0 then
				lastcheck = GetTime()
			else
				lastcheck = castcheck
			end
			castcheck = GetTime()
			
			self.min = self.min + (castcheck - lastcheck)
			self.max = self.max + (castcheck - lastcheck)
			self:SetMinMaxValues(self.min, self.max)
		else
			castcheck = 0
		end
		
		elapsed = GetTime()
		if(elapsed > self.max) then
			self:Hide()
			self:SetScript('OnUpdate', nil)
		else
			self:SetValue(self.min + (elapsed - self.min))

			if(self.Text) then
				if(self.OverrideText) then
					self:OverrideText(elapsed)
				else
					self.Text:SetFormattedText('%.1f', self.max - elapsed)
				end
			end
		end
	end
end

local function Melee(self, _, _, event, GUID, _, _, _, tarGUID, _, missType, spellName)
	local bar = self.Swing
	
	if(UnitGUID(self.unit) == tarGUID) then
	
		if(string.find(event, 'MISSED')) then
			if(missType == 'PARRY') then
				bar.max = bar.min + ((bar.max - bar.min) * 0.6)
				bar:SetMinMaxValues(bar.min, bar.max)
			end
		end
		
	elseif(UnitGUID(self.unit) == GUID) then
		
		-- SPELL_EXTRA_ATTACKS
		local swordprocc = false
		if(event == 'SPELL_EXTRA_ATTACKS' and (spellName == GetSpellInfo(12815) or spellName == GetSpellInfo(13964))) then
			swordprocc = true
		end
		-- SWING_DAMAGE, SWING_MISS, SPELL_CAST_SUCCESS
		if(not string.find(event, 'SWING') and not string.find(event, 'SPELL_CAST_SUCCESS')) then return end
		if(string.find(event, 'SPELL_CAST_SUCCESS')) then
			if(spellName ~= GetSpellInfo(47450) and spellName ~= GetSpellInfo(47520) and spellName ~= GetSpellInfo(56815) and spellName ~= GetSpellInfo(48996) and spellName ~= GetSpellInfo(48480)) then return end
		end
		
		if swordprocc == true then
			swordprocc = false
		else
			bar.min = GetTime()
			bar.max = bar.min + UnitAttackSpeed(self.unit)
			local itemId = GetInventoryItemID("player", 17)
			
			if itemId ~= nil then
				local _, _, _, _, _, itemType = GetItemInfo(itemId)
				
				if itemType ~= GetItemInfo(25) then -- Worn Shortsword, little "hack" for language support
					bar:Show()
					bar:SetMinMaxValues(bar.min, bar.max)
					bar:SetScript('OnUpdate', OnDurationUpdate)
				else
					bar:Hide()
					bar:SetScript('OnUpdate', nil)
				end
			else
				bar:Show()
				bar:SetMinMaxValues(bar.min, bar.max)
				bar:SetScript('OnUpdate', OnDurationUpdate)
			end
		end
		
	end
end

local function Ranged(self, event, unit, spellName)
	if(spellName ~= GetSpellInfo(75) and spellName ~= GetSpellInfo(5019)) then return end

	local bar = self.Swing
	bar.min = GetTime()
	bar.max = bar.min + UnitRangedDamage(unit)

	bar:Show()
	bar:SetMinMaxValues(bar.min, bar.max)
	bar:SetScript('OnUpdate', OnDurationUpdate)
end

local function GlobalCoolDown(self)
	local class = UnitClass("player")
	start, duration = GetSpellCooldown(classMap[class])
	
	local bar = self.Swing
	bar.min = GetTime()
	bar.max = bar.min + duration
	
	bar:Show()
	bar:SetMinMaxValues(bar.min, bar.max)
	bar:SetScript('OnUpdate', OnDurationUpdate)
end

local function Ooc(self)
	local swing = self.Swing
	swing:Hide()
end

local function Enable(self, unit)
	local swing = self.Swing
	if(swing and unit == 'player') then
		if(not swing.disableGlobalCoolDown) then
			self:RegisterEvent('ACTIONBAR_UPDATE_COOLDOWN', GlobalCoolDown(self))
		end
	
		if(not swing.disableRanged) then
			self:RegisterEvent('UNIT_SPELLCAST_SUCCEEDED', Ranged)
		end
		
		if(not swing.disableMelee) then
			self:RegisterEvent('COMBAT_LOG_EVENT_UNFILTERED', Melee)
		end
		
		if(not swing.disableOoc) then
			self:RegisterEvent('PLAYER_REGEN_ENABLED', Ooc)
		end
		
		swing:Hide()
		if(not swing:GetStatusBarTexture() and not swing:GetTexture()) then
			swing:SetStatusBarTexture([=[Interface\TargetingFrame\UI-StatusBar]=])
		end

		return true
	end
end

local function Disable(self)
	local swing = self.Swing
	if(swing) then
		if(not swing.disableGlobalCoolDown) then
			self:UnregisterEvent('ACTIONBAR_UPDATE_COOLDOWN', GlobalCoolDown)
		end
		
		if(not swing.disableRanged) then
			self:UnregisterEvent('UNIT_SPELLCAST_SUCCEEDED', Ranged)
		end

		if(not swing.disableMelee) then
			self:UnregisterEvent('COMBAT_LOG_EVENT_UNFILTERED', Melee)
		end
		
		if(not swing.disableOoc) then
			self:UnregisterEvent('PLAYER_REGEN_ENABLED', Ooc)
		end
	end
end

oUF:AddElement('Swing', nil, Enable, Disable)
