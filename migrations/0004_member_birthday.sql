-- De geboortedag van wie meedoet in dit huis, als `jjjj-mm-dd`. Net als bij een
-- kind: staat hij er, dan is die persoon elk jaar op die dag vanzelf jarig in
-- de agenda. Per huis, want het is dezelfde regel als nickname/emoji/color.
ALTER TABLE memberships ADD COLUMN birthday TEXT;
