-- Fixes broken dragger/draggee relationship between merchants and animals
-- Based on "fix/stuck-merchants" from DFHack

local help = [====[

fix/merchant-relationships
===================

Fixes the Dragger and Draggee relationship ids on merchants and the animals following them. 

This should only be run if a mechant does not appear to be dragging their animal to the trade depot. 
This happens because the Dragger value of the animal is not set or the Draggee value of the mechant is not set. 
The merchant will never stop 'unloading' and no items will leave the animal's inventory.

This script simply scans for any mechants (animals are mechants too). 
It uses the animal's 'following' value to determine who the relationship should be between. 
If the relationships are wrong, it then sets the Dragger/Draggee values appropriately.

Once these values are fixed, the trader should unload the animal's cargo, the animal will likely remain wherever it was when you ran this until the merchant leaves.

Run ``fix/merchant-relationships -n`` or ``fix/merchant-relationships --dry-run`` to list all merchants that would have their relationships fixed.

]====]


function getEntityName(u)
    local civ = df.historical_entity.find(u.civ_id)
    if not civ then return 'unknown civ' end
    return dfhack.TranslateName(civ.name)
end

function formatMerchant(u, dry_run)
    dry_run = dry_run or false
    return ("%s ID(%d) Name(%s) Following(%d) Civ(%s) Race(%s)"):format(
                dry_run and 'DRYRUN' or 'FIXED',
                u.id,
                u.name.has_name and dfhack.df2console(dfhack.TranslateName(dfhack.units.getVisibleName(u))) or 'NO_NAME',
                u.following and u.following.id or -1,
                dfhack.df2console(getEntityName(u)), 
                dfhack.units.getRaceName(u)
            )
end

function fixMerchantRelationships(args)
    local dry_run = false
    for _, arg in pairs(args) do
        if args[1]:match('-h') or args[1]:match('help') then
            print(help)
            return
        elseif args[1]:match('-n') or args[1]:match('dry') then
            dry_run = true
        end
    end    
    for _,u in pairs(df.global.world.units.active) do
        if u.flags1.merchant and u.following then
            if u.relationship_ids.Dragger ~= u.following.id then
                print(formatMerchant(u, dry_run))
                if not dry_run then
                    u.relationship_ids.Dragger = u.following.id
                end
            end
            if u.following.relationship_ids.Draggee ~= u.id then
                print(formatMerchant(u.following, dry_run))
                if not dry_run then
                    u.following.relationship_ids.Draggee = u.id
                end
            end
        end
    end
end

fixMerchantRelationships{...}