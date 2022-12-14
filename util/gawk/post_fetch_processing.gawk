@include "base.gawk"


BEGIN {
    write_after_line("> main processing");
}

@include "input_processing.gawk"

END {
    main_processing();
    write("> main processing end");
}

function main_processing(    ref){
    generate_missing_refs();

    unlock_deletion();
    if(!deletion_allowed){
        write(deletion_blocked_by);
    }

    for(ref in refs){
        state_to_action(ref);
    }
    actions_to_operations();
    operations_to_refspecs();
    refspecs_to_stream();
}
function state_to_action(ref,    remote_sha, track_sha, side, is_victim, ref_type){
    if(remote_empty[side_any])
        return;

    for(side in sides){
        remote_sha[side] = refs[ref][side][remote][sha_key];
        track_sha[side] = refs[ref][side][track][sha_key];
    }

    remote_sha[equal] = remote_sha[side_a] == remote_sha[side_b];
    track_sha[equal] = track_sha[side_a] == track_sha[side_b];
    
    if(remote_sha[equal] && track_sha[equal] && track_sha[side_a] == remote_sha[side_b])
        return;

    remote_sha[common] = remote_sha[equal] ? remote_sha[side_a] : "";
    remote_sha[empty] = !(remote_sha[side_a] || remote_sha[side_b]);
    remote_sha[empty_any] = !remote_sha[side_a] || !remote_sha[side_b];

    track_sha[common] = track_sha[equal] ? track_sha[side_a] : "";
    track_sha[empty] = !(track_sha[side_a] || track_sha[side_b]);
    track_sha[empty_any] = !track_sha[side_a] || !track_sha[side_b];

    is_victim = use_victim_sync(ref);

    if(remote_sha[empty]){
        # A branch in the ref was deleted manually in both repos.

        trace(ref ": action-remove-tracking-as-unknown-on-both-remotes");
        a_remove_tracking_both[ref];

        return;
    }

    # ! All further actions assume that remote refs are unequal.

    if(track_sha[empty]){
        trace("!Warning!");
        trace("!! Something went wrong for " ref ". It is still untracked.");
        trace("!! Possibly the program or the network were interrupted.");
        trace("!! We will try to sync it later (during the second sync pass).");

        return;
    }

    if(del_to_action(ref, is_victim, remote_sha, track_sha)){
        return;
    }
    if(move_to_refspec(ref, conv_move, is_victim)){
        return;
    }
    if(move_to_refspec(ref, victim_move, is_victim)){
        return;
    }
    if(victim_move_to_refspec(ref, remote_sha, track_sha)){
        return;
    }

    ref_type = is_victim ? "victim" : "conv";
    trace(ref "; " ref_type ":action-solve-all-others; it has different track or/and remote branch commits");
    if(is_victim){
        a_victim_solve[ref];
    }else{
        a_conv_solve[ref];
    }
}
function del_to_action(ref, is_victim, remote_sha, track_sha,    side, aside, deletion_state, unowned_ref, action_key){
    if(!track_sha[equal]){
        return;
    }

    for(side in sides){
        aside = asides[side];

        deletion_state = !remote_sha[side] && remote_sha[aside] == track_sha[common];
        if(!deletion_state){
            continue;
        }

        if(is_victim){
            if(deletion_allowed){
                trace(ref ": action-del-victim on " origin[aside] "; it is disappeared from " origin[side]);
                a_del[aside][ref];
            }else{
                trace(ref "; action-blocked-del-victim-restore on " origin[aside] "; disappeared from " origin[side]);
                a_restore_del[ref];
            }

            return 1;
        }

        unowned_ref = index(ref, prefix[aside]) == 1;

        if(!deletion_allowed || unowned_ref){
            action_key = "action-blocked-del-conv";
            if(unowned_ref){
                action_key = action_key "&unowned-ref";
            }

            trace(ref "; " action_key " on " origin[aside] "; disappeared from " origin[side]);
            a_conv_solve[ref];
            append_by_val(out_notify_solving, "blocked-del-conventional-ref | " prefix[side] " | " ref " | " action_key " | restoring-to:" refs[ref][side][track][sha_key]);

            return 1;
        }
        
        trace(ref ": action-del-conv on " origin[aside] "; it is disappeared from " origin[side]);
        a_del[aside][ref];

        return 1;
    }
}
function move_to_refspec(ref, source_refs, is_victim,    ref_item, action_sha, cmd, parent_sha, parent_side, child_side, action_key, moving_back, owner_action, force_key){
    for(ref_item in source_refs){
        if(ref_item != ref){
            continue;
        }
        for(action_sha in source_refs[ref_item]){}

        break;
    }
    if(ref_item != ref){
        return;
    }

    cmd = "git merge-base " refs[ref][side_a][track][ref_key] " " refs[ref][side_b][track][ref_key];
    
    cmd | getline parent_sha;
    close(cmd);

    if(parent_sha == refs[ref][side_a][track][sha_key]){
        parent_side = side_a;
    } else if(parent_sha == refs[ref][side_b][track][sha_key]){
        parent_side = side_b;
    } else{
        trace(ref " rejected-move; " origin[side_a] " & " origin[side_b] " lost direct inheritance at " parent_sha);

        return;
    }

    child_side = asides[parent_side];
    action_key = "action-fast-forward";

    moving_back = parent_sha == action_sha;
    if(moving_back){
        if(!is_victim){
            owner_action = index(ref, prefix[parent_side]) == 1;
            if(!owner_action){
                # Moving back from a non-owner side is forbidden.
                return;
            }
        }
        parent_side = child_side;
        child_side = asides[parent_side];
        force_key = "+";
        action_key = "action-moving-back";

        append_by_val(out_notify_solving, "moving-back | " prefix[parent_side] " | " ref " | out-of " refs[ref][parent_side][track][sha_key] " to " refs[ref][child_side][track][sha_key]);
    }
    
    trace(ref " " action_key "; from " origin[parent_side] " to " origin[child_side]);
    out_push[parent_side] = out_push[parent_side] "  " force_key refs[ref][child_side][track][ref_key] ":" refs[ref][parent_side][remote][ref_key];

    # Let's inform a calling logic that we've processed the current ref.
    return 1;
}
function victim_move_to_refspec(ref, remote_sha, track_sha,    ref_item, action_sha, source_side, target_side){
    for(ref_item in victim_move){
        if(ref_item != ref){
            continue;
        }
        for(action_sha in victim_move[ref_item]){}

        break;
    }
    if(ref_item != ref){
        return;
    }

    # The idea below is to ignore a candidate ref if sha was changed since last check.
    # E.g. obey ra==la & rb==lb & ra!=rb

    if(remote_sha[equal])
        return;
    if(track_sha[equal])
        return;

    if(remote_sha[side_a] != track_sha[side_a])
        return;
    if(remote_sha[side_b] != track_sha[side_b])
        return;

    if(remote_sha[side_a] != action_sha && remote_sha[side_b] != action_sha)
        return;

    if(remote_sha[side_a] == action_sha){
        source_side = side_a;
    } else if(remote_sha[side_b] == action_sha){
        source_side = side_b;
    } else {
        return;
    }

    target_side = asides[source_side];

    trace(ref " action-non-fast-forward to " action_sha);
    out_push[target_side] = out_push[target_side] "  +" refs[ref][source_side][track][ref_key] ":" refs[ref][target_side][remote][ref_key];

    # Let's inform a calling logic that we've processed the current ref.
    return 1;
}
function actions_to_operations(    side, aside, ref, restore_both, track_sha, another_track_sha, remote_sha, ref_owner){
    restore_both = remote_empty[side_both];
    for(side in sides){
        if(!remote_empty[side]){
            continue
        }
        for(ref in refs){
            track_sha = refs[ref][side][track][sha_key];
            if(!track_sha){
                continue;
            }
            if(restore_both){
                op_push_restore_from_track[side][ref];
                append_by_val(out_notify_solving, "restore-both-sides | " side " | " ref " | restoring-to:" track_sha);
            }else{
                aside = asides[side];
                another_track_sha = refs[ref][aside][track][sha_key];

                op_push_restore_from_another[side][ref];
                append_by_val(out_notify_solving, "restore-side-from-another | " side " | " ref " | restoring-to:" another_track_sha);
            }
        }
    }
    for(ref in a_remove_tracking_both){
        for(side in sides){
            track_sha = refs[ref][side][track][sha_key];
            if(!track_sha){
                continue;
            }
            op_remove_both_tracking[side][ref];
            append_by_val(out_notify_solving, "tracking-removed | " side " | " ref " | " track_sha);
        }
    }
    for(ref in a_restore_del){
        for(side in sides){
            track_sha = refs[ref][side][track][sha_key];
            remote_sha = refs[ref][side][remote][sha_key]
            if(remote_sha){
                continue;
            }
            op_push_restore_from_track[side][ref];
            append_by_val(out_notify_solving, "blocked-del-victim-restore | " side " | " ref " | restoring-to:" sha);
        }
    }

    for(side in a_del){
        for(ref in a_del[side]){
            op_del_track[ref];
            op_push_del[side][ref];
        }
    }

    for(side in sides){
        aside = asides[side];
        for(ref in a_conv_solve){
            ref_owner = index(ref, prefix[side]) == 1;

            if(!ref_owner){
                continue;
            }

            if(refs[ref][side][remote][sha_key]){
                op_push_nff[aside][ref];
            } else if(refs[ref][aside][remote][sha_key]){
                op_push_nff[side][ref];
            }
        }
    }
}
function operations_to_refspecs(    side, aside, ref){
    for(side in op_remove_both_tracking){
        for(ref in op_remove_both_tracking[side]){
            out_remove_tracking = out_remove_tracking "  " origin[side] "/" ref;
        }
    }

    for(side in sides){
        for(ref in op_del_track){
            if(refs[ref][side][track][sha_key]){
                out_remove_tracking = out_remove_tracking "  " origin[side] "/" ref;
            }
        }
    }

    for(side in op_push_restore_from_track){
        for(ref in op_push_restore_from_track[side]){
            out_push[side] = out_push[side] "  +" refs[ref][side][track][ref_key] ":" refs[ref][side][remote][ref_key];
        }
    }

    for(side in op_push_restore_from_another){
        aside = asides[side];
        for(ref in op_push_restore_from_another[side]){
            out_push[side] = out_push[side] "  +" refs[ref][aside][track][ref_key] ":" refs[ref][side][remote][ref_key];
        }
    }

    for(side in op_push_del){
        for(ref in op_push_del[side]){
            out_push[side] = out_push[side] "  +:" refs[ref][side][remote][ref_key];
            
            append_by_val(out_notify_del, "deletion | " prefix[side] " | " ref " | " refs[ref][side][remote][sha_key]);
        }
    }

    for(side in op_push_nff){
        aside = asides[side];
        for(ref in op_push_nff[side]){
            out_push[side] = out_push[side] "  +" refs[ref][aside][track][ref_key] ":" refs[ref][side][remote][ref_key];

            if(refs[ref][side][remote][sha_key]){
                append_by_val(out_notify_solving, "conflict-solving | " prefix[side] " | " ref " | out-of " refs[ref][side][remote][sha_key] " to " refs[ref][aside][remote][sha_key]);
            }
        }
    }
    set_victim_refspec();

    # We may use post fetching as workaround for network fails and program interruptions.
    # Also FF-updating may fail in case of rare conflicting with a remote repo.
    # Without the post fetching these cases will not be resolved ever.
    # But we don't use it for now as we migrated to preprocessing git fetching.
    for(side in op_post_fetch){
        for(ref in op_post_fetch[side]){
            out_post_fetch[side] = out_post_fetch[side] "  +" refs[ref][side][remote][ref_key] ":" refs[ref][side][track][ref_key];
        }
    }
}

function set_victim_refspec(    ref, remote_sha_a, track_sha_a, track_sha_a_txt, remote_sha_b, track_sha_b, track_sha_b_txt, cmd, newest_sha, side_winner, side_victim){
    for(ref in a_victim_solve){
        # We expects that "no sha" cases will be processed by common NFF-solving actions.
        # But this approach with variables help to solve severe errors. Also it makes code more resilient.

        remote_sha_a = refs[ref][side_a][remote][sha_key];
        track_sha_a = refs[ref][side_a][track][sha_key];

        remote_sha_b = refs[ref][side_b][remote][sha_key];
        track_sha_b = refs[ref][side_b][track][sha_key];

        # d_trace("a " ref "; track_sha_a:" track_sha_a "; remote_sha_a:" remote_sha_a);
        # d_trace("b " ref "; track_sha_b:" track_sha_b "; remote_sha_b:" remote_sha_b);

        if(track_sha_a && track_sha_b){
            cmd = "git rev-list " refs[ref][side_a][track][ref_key] " " refs[ref][side_b][track][ref_key] " --max-count=1"
            cmd | getline newest_sha;
            close(cmd);
        } else if(track_sha_a){
           newest_sha =  track_sha_a;
        } else if(track_sha_b){
           newest_sha =  track_sha_b;
        }

        if(newest_sha == track_sha_a){
            side_winner = side_a
            side_victim = side_b
        } else if(newest_sha == track_sha_b){
            side_winner = side_b
            side_victim = side_a
        } else {
            trace("unexpected behavior during victim solving | " ref);

            continue;
        }

        track_sha_a_txt = track_sha_a ? track_sha_a : "<no-sha>"
        track_sha_b_txt = track_sha_b ? track_sha_b : "<no-sha>"
        trace("victim-solving: " ref " on " origin[side_winner] " beat " origin[side_victim] " with " track_sha_a_txt " vs " track_sha_b_txt);

        out_push[side_victim] = out_push[side_victim] "  +" refs[ref][side_winner][track][ref_key] ":" refs[ref][side_victim][remote][ref_key];

        append_by_val(out_notify_solving, "victim-solving | " prefix[side_victim] " | " ref " | out-of " refs[ref][side_victim][remote][sha_key] " to " refs[ref][side_winner][remote][sha_key]);
    }
}

function refspecs_to_stream(){
    print out_remove_tracking;
    print out_notify_del[val];

    print out_push[side_a];
    print out_push[side_b];
    print out_notify_solving[val];

    print out_post_fetch[side_a];
    print out_post_fetch[side_b];

    # Must print finishing line otherwise previous empty lines will be ignored by mapfile command in bash.
    print "{[end-of-results]}"
}


