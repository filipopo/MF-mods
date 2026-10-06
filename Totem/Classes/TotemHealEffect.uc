//=============================================================================
// TotemHealEffect
// Applied to players/allies for Heal-Over-Time (HoT) and emergency invulnerability.
//=============================================================================
class TotemHealEffect extends Inventory;

var int HealPerTick;
var int MaxTicks;
var int CurrentTicks;
var float TickInterval;
var float GracePeriodRemaining;
var bool bInvulnerable;
var bool bActivated;

function ActivateBuff(int InHealPerTick, int InTotalTicks, float InInterval, float InGracePeriod)
{
    HealPerTick = InHealPerTick;
    MaxTicks = InTotalTicks;
    CurrentTicks = 0;
    TickInterval = InInterval;
    GracePeriodRemaining = InGracePeriod;
    bInvulnerable = (InGracePeriod > 0.0);
    bActivated = true;

    SetTimer(TickInterval, true);
}

function Timer()
{
    local Pawn P;

    if (!bActivated)
        return;

    P = Pawn(Owner);
    if (P == None || P.Health <= 0)
    {
        Destroy();
        return;
    }

    if (GracePeriodRemaining > 0.0)
    {
        GracePeriodRemaining -= TickInterval;
        if (GracePeriodRemaining <= 0.0)
        {
            GracePeriodRemaining = 0.0;
            bInvulnerable = false;
        }
    }

    if (P.Health < P.Default.Health)
        P.Health = Min(P.Default.Health, P.Health + HealPerTick);

    CurrentTicks++;
    if (CurrentTicks >= MaxTicks && !bInvulnerable)
        Destroy();
}

function int ArmorPriority(name DamageType)
{
    if (!bInvulnerable)
        return 0;
    return AbsorptionPriority;
}

function int ArmorAbsorbDamage(int Damage, name DamageType, vector HitLocation)
{
    if (bInvulnerable && DamageType != 'Suicided' && DamageType != 'Crushed')
        return 0;
    return Damage;
}

defaultproperties
{
     bIsAnArmor=True
     AbsorptionPriority=2000000
     bHidden=True
}
