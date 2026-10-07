//=============================================================================
// Molotov cocktail projectile that explodes on contact.
//=============================================================================

class MolotovProjectileAlt extends Grenade2;

// override explosion to spawn fire too
simulated function Explosion(vector HitLocation, Rotator HitRotation)
{
    local MolotovFire MF;

    MF = Spawn(class'MolotovFire', Instigator, , HitLocation);
    if (MF != None)
        MF.Instigator = Instigator;

    Super.Explosion(HitLocation, HitRotation);
}

defaultproperties
{
     Damage=40.000000
     MyDamageType=MolotovDOTMolotov
}
