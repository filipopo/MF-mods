//=============================================================================
// Molotov cocktail weapon - grenade that creates burning fire areas.
//=============================================================================

class Molotov extends Grenades;

#exec TEXTURE IMPORT NAME=MolotovIcon FILE=Textures\molotov_icon.bmp GROUP=Icons MIPS=OFF Flags=2

defaultproperties
{
     MaxClipAmmo=2
     ProjectileClass=Class'Molotov.MolotovProjectile'
     AltProjectileClass=Class'Molotov.MolotovProjectileAlt'
     DeathMessage="%k Set %o on Fire."
     PickupMessage="Loaded up Molotov cocktails."
     ItemName="Molotov Cocktail"
     WeaponIcon=(X=0,Y=0,W=64,H=64,t=Texture'Molotov.Icons.MolotovIcon')
}
