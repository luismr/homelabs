#!/bin/bash
# Quick SSH helper for homelabs cluster nodes

case "$1" in
  master|m)
    ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null vagrant@192.168.5.200
    ;;
  worker1|w1)
    ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null vagrant@192.168.5.201
    ;;
  worker2|w2)
    ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null vagrant@192.168.5.202
    ;;
  worker3|w3)
    ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null vagrant@192.168.5.203
    ;;
  *)
    echo "Usage: $0 {master|m|worker1|w1|worker2|w2|worker3|w3}"
    echo ""
    echo "Examples:"
    echo "  $0 master   # SSH to master node"
    echo "  $0 w1       # SSH to worker1"
    echo ""
    echo "Or SSH directly:"
    echo "  ssh vagrant@192.168.5.200  # master"
    echo "  ssh vagrant@192.168.5.201  # worker1"
    echo "  ssh vagrant@192.168.5.202  # worker2"
    echo "  ssh vagrant@192.168.5.203  # worker3"
    echo ""
    echo "  ssh root@192.168.5.200     # root access"
    exit 1
    ;;
esac

