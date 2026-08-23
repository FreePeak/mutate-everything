--!strict
-- Shared type definitions for MUTATE! Steal & Fuse.

export type Rarity = "Common" | "Uncommon" | "Rare" | "Epic" | "Legendary" | "Mythic" | "MutantGod"

export type Mutation = "None" | "Neon" | "Cosmic" | "Void"

export type CreatureSpecies = {
	id: string,
	name: string,
	rarity: Rarity,
	baseIncome: number,
	cost: number,
	bodyColor: Color3,
	accentColor: Color3,
	scale: number,
	shape: "Blob" | "Tall" | "Wide",
}

export type Creature = {
	uid: string,
	speciesId: string,
	name: string,
	income: number,
	mutation: Mutation,
	colorA: Color3,
	colorB: Color3,
	scale: number,
	generation: number,
	parents: { string },
}

export type PlayerState = {
	userId: number,
	cash: number,
	rebirths: number,
	incomeMultiplier: number,
	baseSlots: number,
	lastLockTime: number,
	lockExpireAt: number,
	unlockCooldownUntil: number,
}

export type PublicCreatureView = {
	uid: string,
	name: string,
	income: number,
	mutation: Mutation,
	rarity: Rarity,
	generation: number,
}

return nil
