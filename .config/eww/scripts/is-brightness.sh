if ddcutil detect 2>/dev/null | grep -q "Display"; then
    echo "true"
else
    echo "false"
fi
