# Initialization tests -- most units will start including this.

test "(init) Restart killed instances" {
    foreach type {redis} {
        foreach_${type}_id id {
            if {[get_instance_attrib $type $id pid] == -1} {
                puts -nonewline "$type/$id "
                flush stdout
                restart_instance $type $id
            }
        }
    }
}

test "Cluster nodes are reachable" {
    foreach_redis_id id {
        # Every node should just know itself.
        assert {[R $id ping] eq {PONG}}
    }
}

test "Cluster nodes hard reset" {
    foreach_redis_id id {
        catch {R $id flushall} ; # May fail for readonly slaves.
        R $id cluster reset hard
        R $id config set cluster-node-timeout 3000
    }
}

test "Cluster Join and auto-discovery test" {
    # Join node 0 with 1, 1 with 2, ... and so forth.
    # If auto-discovery works all nodes will know every other node
    # eventually.
    set ids {}
    foreach_redis_id id {lappend ids $id}
    for {set j 0} {$j < [expr [llength $ids]-1]} {incr j} {
        set a [lindex $ids $j]
        set b [lindex $ids [expr $j+1]]
        set b_port [get_instance_attrib redis $b port]
        R $a cluster meet 127.0.0.1 $b_port
    }

    foreach_redis_id id {
        wait_for_condition 1000 50 {
            [llength [get_cluster_nodes $id]] == [llength $ids]
        } else {
            fail "Cluster failed to join into a full mesh."
        }
    }
}

test "Before slots allocation, all nodes report cluster failure" {
    assert_cluster_state fail
}
