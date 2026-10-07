//=============================================================================
// Molotov cocktail projectile that creates a burning fire area upon exploding.
//=============================================================================

class MolotovProjectile extends Grenade1;

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
     Damage=44.000000
     MyDamageType=MolotovDOTMolotov
}
