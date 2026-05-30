#!/bin/bash
# tui for yaml-gen, dir-and dir-rm
if command -v dialog >/dev/null 2>&1; then
    choice=$(dialog --stdout --title "CCT-ct TUI" --menu "Choose an option:" 10 50 3 \
        1 "Generate docker-compose.yaml" \
        2 "Create environment directories" \
        3 "Remove environment directories")
else
    echo "dialog command not found. Please install dialog to use the TUI."
    exit 1
fi

case $choice in
    1)
        form_values=$(dialog --stdout --title "Generate docker-compose.yaml" --form "Enter details:" 14 50 0 \
            "Number of servers:" 1 1 "" 1 25 5 0 \
            "Starting port:" 2 1 "" 2 25 5 0 \
            "Version (20.04|24.04|26.04):" 3 1 "26.04" 3 30 8 0 \
            "Image name (optional):" 4 1 "" 4 25 50 0 \
            "Filename (optional):" 5 1 "docker-compose.yaml" 5 25 50 0)
        servers=$(printf '%s\n' "$form_values" | sed -n '1p')
        port_start=$(printf '%s\n' "$form_values" | sed -n '2p')
        version=$(printf '%s\n' "$form_values" | sed -n '3p')
        image_name=$(printf '%s\n' "$form_values" | sed -n '4p')
        filename=$(printf '%s\n' "$form_values" | sed -n '5p')
        ./yaml-gen.sh "$servers" "$port_start" "$version" "$image_name" "$filename"
        ;;
    2)
        amount=$(dialog --stdout --title "Create environment directories" --inputbox "Enter the number of directories to create:" 10 50)
        ./dir-gen.sh "$amount" "env_template"
        ;;
    3)
        amount=$(dialog --stdout --title "Remove environment directories" --inputbox "Enter the number of directories to remove:" 10 50)
        ./dir-rm.sh "$amount"
        ;;
    *)
        echo "Invalid choice."
        exit 1
        ;;
esac