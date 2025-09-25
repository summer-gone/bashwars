#!/bin/bash
#
# BASH WARS - Simple drug merchant game for BASH
# Based on "Drug Wars" by John E. Dell, 1984
#

echo " _______    ______    ______   __    __        __       __   ______   _______    ______  "
echo "|       \\  /      \\  /      \\ |  \\  |  \\      |  \\  _  |  \\ /      \\ |       \\  /      \\ "
echo "| \$\$\$\$\$\$\$\\|  \$\$\$\$\$\$\\|  \$\$\$\$\$\$\\| \$\$  | \$\$      | \$\$ / \\ | \$\$|  \$\$\$\$\$\$\\| \$\$\$\$\$\$\$\\|  \$\$\$\$\$\$\\ "
echo "| \$\$__/ \$\$| \$\$__| \$\$| \$\$___\\\$\$| \$\$__| \$\$      | \$\$/  \$\\| \$\$| \$\$__| \$\$| \$\$__| \$\$| \$\$___\\\$\$ "
echo "| \$\$    \$\$| \$\$    \$\$ \\\$\$    \\ | \$\$    \$\$      | \$\$  \$\$\$\\ \$\$| \$\$    \$\$| \$\$    \$\$ \\\$\$    \\  "
echo "| \$\$\$\$\$\$\$\\| \$\$\$\$\$\$\$\$ _\\\$\$\$\$\$\$\\| \$\$\$\$\$\$\$\$      | \$\$ \$\$\\\$\$\\\$\$| \$\$\$\$\$\$\$\$| \$\$\$\$\$\$\$\\ _\\\$\$\$\$\$\$\$ "
echo "| \$\$__/ \$\$| \$\$  | \$\$|  \\__| \$\$| \$\$  | \$\$      | \$\$\$\$  \\\$\$\$\$| \$\$  | \$\$| \$\$  | \$\$|  \\__| \$\$ "
echo "| \$\$    \$\$| \$\$  | \$\$ \\\$\$    \$\$| \$\$  | \$\$      | \$\$\$    \\\$\$\$| \$\$  | \$\$| \$\$  | \$\$ \\\$\$    \$\$ "
echo " \\\$\$\$\$\$\$\$  \\\$\$   \\\$\$  \\\$\$\$\$\$\$  \\\$\$   \\\$\$       \\\$\$      \\\$\$ \\\$\$   \\\$\$ \\\$\$   \\\$\$  \\\$\$\$\$\$\$  "

# Names and event flavour text
items=("Weed" "Ecstasy" "Meth" "Cocaine" "Heroin")
locations=("Bronx" "Queens" "Brooklyn" "Manhattan" "Staten Island")
messages=(
    "👮 Border Patrol seizes a huge shipment..."
    "🔥 Warehouse fire burns through stock..."
    "👽 Feds intercept a major delivery..."
    "⚔️ Gang war disrupts the supply chain..."
    "🫨 A market panic causes a run on supplies..."
    "🏚️ A large stash house is busted..."
    "🚧 Police checkpoints choke supply routes..."
    "🧨 Gang attack destroys a warehouse..."
    "🕵️ Undercover operation causes massive seizure..."
)

# Initialisation
prices=(0 0 0 0 0)
spike_duration=(0 0 0 0 0)
inventory=(0 0 0 0 0)
current_location=0
money=2000
debt=4000
bank=0
days=14
bank_fee=50
interest=10
travels_today=0

# Item prices and deviation
base_price=(200 350 500 800 1000)
std_dev=(40 70 100 175 200)

# Input prompt
read_input() {
    local prompt="$1"
    local var_name="$2"
    local input
    while true; do
        read -p "$prompt" input
        if [[ $input =~ ^[0-9]+$ ]]; then
            eval "$var_name=$input"
            return 0
        else
            echo "❌ Invalid input."
        fi
    done
}

# Check if player has no items
has_inventory() {
    for qty in "${inventory[@]}"; do
        if ((qty > 0)); then
            return 0
        fi
    done
    return 1
}

# Generate new item prices
new_prices() {
    for i in "${!items[@]}"; do
        if ((spike_duration[i] == 0)); then
            local mean=${base_price[i]}
            local sd=${std_dev[i]}

            # Normal distribution generation with awk (Box-Muller transform)
            local price
            price=$(awk -v mean="$mean" -v sd="$sd" -v seed="$RANDOM" 'BEGIN {
                srand(seed);
                u1 = rand(); u2 = rand();
                z0 = sqrt(-2*log(u1)) * cos(2*3.14159*u2);
                p = int(mean + z0*sd);
                print p;
            }')

            # Clamp prices to prevent extreme outliers
            local min_p=$((mean - 3 * sd))
            local max_p=$((mean + 3 * sd))
            ((price < min_p)) && price=$min_p
            ((price > max_p)) && price=$max_p
            ((price < 1)) && price=1

            prices[$i]=$price
        fi
    done
}

# Adjust existing prices for travel events
travel_prices() {
    for i in "${!items[@]}"; do
        local current_price=${prices[i]}
        local magnitude=$(((RANDOM % 11) + 10))
        if ((RANDOM % 2 == 0)); then
            local percent_change=$((-magnitude))
        else
            local percent_change=$magnitude
        fi
        local adjustment=$((current_price * percent_change / 100))
        local new_price=$((current_price + adjustment))
        ((new_price < 1)) && new_price=1
        prices[$i]=$new_price
    done
}

# Random events for new day transition
newday_event() {
    local roll=$((RANDOM % 100))
    if ((roll < 5)); then
        echo "🔫 You were robbed at home! They took your entire stash."
        inventory=(0 0 0 0 0)

    elif ((roll < 15)); then
        echo "🚨 Police raid! They confiscated half of your stash."
        for i in "${!inventory[@]}"; do
            inventory[$i]=$((inventory[i] / 2))
        done

    elif ((roll < 25)); then
        local loss=$((money > 500 ? 500 : money))
        echo "💰 Thieves broke in! They stole \$$loss!"
        money=$((money - loss))

    elif ((roll < 40)); then
        local idx=$((RANDOM % ${#items[@]}))
        if ((spike_duration[idx] == 0)); then
            local msg_idx=$((RANDOM % ${#messages[@]}))
            echo "🌝 A peaceful evening."
            echo "${messages[msg_idx]}"
            echo "📈 Prices for ${items[idx]} skyrocket!"
            prices[idx]=$((prices[idx] * 2))
            spike_duration[idx]=$((2 + RANDOM % 2)) # Spike for 2-3 days
        fi

    else
        echo "🌝 A peaceful evening."
    fi

    for i in "${!spike_duration[@]}"; do
        if ((spike_duration[i] > 0)); then
            spike_duration[i]=$((spike_duration[i] - 1))
            if ((spike_duration[i] == 0)); then
                echo "📉 The ${items[i]} market stabilizes."
                new_prices
            fi
        fi
    done
}

# Hide item function for Police Stop event
hide_item() {
    if ! has_inventory; then
        echo "😎 ...but you have nothing to hide."
        return
    fi

    echo "Choose one item to hide:"
    for i in "${!items[@]}"; do
        printf -- "  %d) %s\n" "$i" "${items[i]}"
    done

    local choice
    read_input "-> " choice
    local had_item=${inventory[choice]}
    for i in "${!inventory[@]}"; do
        if ((i != choice)); then
            inventory[$i]=0
        fi
    done

    if ((had_item == 0)); then
        echo "🙍 You fumble and they take your whole stash."
    else
        echo "😓 You hid the ${items[$choice]}, but lost everything else."
    fi
}

# Random events for travel
travel_event() {
    local roll=$((RANDOM % 100))
    if ((roll < 10)); then
        local loss=$((money > 300 ? 300 : money))
        echo "🔪 You were mugged on the subway! You lost \$$loss."
        money=$((money - loss))
    elif ((roll < 25)); then
        echo "🚨 Police are conducting random searches at the station!"
        hide_item
    fi
}

# Interface and player options
show_status() {
    echo
    echo "======================================================"
    echo "📍 Location: ${locations[$current_location]} | 🚇 Travel Remaining: $((2 - travels_today))"
    echo "📆 Days remaining: $days — 💰 Cash: \$$money — 💸 Debt: \$$debt ($interest%) — 🏦 Bank: \$$bank"
    echo "------------------------------------------------------"
    echo "  #) Item       Price      Owned"
    echo "------------------------------------------------------"
    for i in "${!items[@]}"; do
        printf "  %d) %-10s \$%-9d %-5d\n" "$i" "${items[i]}" "${prices[i]}" "${inventory[i]}"
    done
    echo "======================================================"
    echo
}

# Buying/Selling items
buy_item() {
    local choice
    read_input "Buy item #: " choice
    if ((choice >= ${#items[@]})); then
        echo "❌ Invalid item."
        return
    fi

    local price=${prices[choice]}
    local max_can_buy=$((money / price))
    echo "(You can afford $max_can_buy ${items[choice]}.)"
    if ((max_can_buy == 0)); then
        return
    fi

    local amount
    read_input "How many? " amount
    if ((amount == 0)); then
        return
    fi

    local cost=$((price * amount))
    if ((cost <= money)); then
        money=$((money - cost))
        inventory[choice]=$((inventory[choice] + amount))
        echo "🛒 Bought $amount ${items[choice]} for \$$cost."
    else
        echo "❌ You can't afford that. (\$$cost)"
    fi
}

sell_item() {
    local choice
    read_input "Sell item #: " choice
    if ((choice >= ${#items[@]})); then
        echo "❌ Invalid item."
        return
    fi
    if ((inventory[choice] == 0)); then
        echo "❌ You don't have any to sell."
        return
    fi

    local amount
    read_input "How many? " amount
    if ((amount == 0)); then
        return
    fi

    if ((amount <= inventory[choice])); then
        local earnings=$((prices[choice] * amount))
        money=$((money + earnings))
        inventory[choice]=$((inventory[choice] - amount))
        echo "💲 Sold $amount ${items[choice]} for \$$earnings."
    else
        echo "❌ You don't have that many to sell."
    fi
}

# Loan System (loan repayment)
loan_menu() {
    echo "💸 Visted the Loan Shark"
    echo "[P]ay debt, [B]orrow or E[X]it?"
    read -r action
    echo
    local amt

    case $action in
    p | P)
        if (( debt == 0 )); then
				    echo "💰 You're debt free!"
            return
        fi
        read_input "Pay how much (Debt: \$$debt): " amt
        if ((amt >= debt && amt <= money)); then
            money=$((money - debt))
            echo "💰 Paid \$$debt, clearing your debt!"
            debt=0
        elif ((amt > 0 && amt <= money)); then
            money=$((money - amt))
            debt=$((debt - amt))
            ((debt < 0)) && debt=0
            echo "💰 Paid \$$amt towards your debt."
        else
            echo "❌ PAYMENT FAILED: Invalid amount or not enough cash."
        fi
        ;;
    b | B)
        read_input "Borrow how much? (\$1000 min): " amt
        if ((amt >= 1000 && amt + debt <= 9000)); then
            tmp_int=$(( interest + ( amt / 200) ))
            read -p "💰 New interest rate: $tmp_int%. Accept? (y/n) " accept
               if [[ $accept == "y" || $accept == "Y" ]]; then
                   debt=$((debt + amt))
                   interest=$tmp_int
                   money=$(( money + amt ))
                   echo "💸 Borrowed \$$amt. Your debt is now \$$debt at $interest%"
               elif [[ $accept == "n" || $accept == "N" ]]; then
                   echo "🤷 Didn't borrow anything."
               else
                   echo "❌ Invalid input."
               fi
        elif ((amt >= 1000 && amt + debt > 9000)); then
            echo "❌ They won't lend you more than \$9000."
        else
            echo "❌ They won't lend you less than \$1000."
        fi
        ;;
    x | X)
        return
        ;;
    *)
        echo "❌ Invalid option."
        ;;
    esac
}

# Bank System (deposit/withdraw cash)
bank_menu() {
    echo "🏦 Arrived at the bank."
    echo "[D]eposit, [W]ithdraw, or E[X]it?"
    read -r action
    echo
    local amt

    case $action in
    d | D)
        read_input "Deposit amount (Fee: \$$bank_fee): " amt
        if ((amt > 0 && amt + bank_fee <= money)); then
            money=$((money - amt - bank_fee))
            bank=$((bank + amt))
            echo "💰 Deposited \$$amt (Fee: \$$bank_fee)."
        else
            echo "❌ DEPOSIT FAILED: Invalid amount or not enough cash for amount + fee."
        fi
        ;;
    w | W)
        read_input "Withdraw amount (ATM Fee \$$bank_fee): " amt
        if ((amt > 0 && amt + bank_fee <= bank)); then
            bank=$((bank - amt - bank_fee))
            money=$((money + amt))
            echo "💵 Withdrew \$$amt (Fee: \$$bank_fee)."
        else
            echo "❌ WITHDRAW FAILED: Invalid amount or not enough in bank for amount + fee."
        fi
        ;;
    x | X)
        return
        ;;
    *)
        echo "❌ Invalid option."
        ;;
    esac
}

# Travel System
travel() {
    if ((travels_today >= 2)); then
        echo "😴 You're too tired to travel again today."
        return
    fi

    echo "Where to? (Tickets \$50)"
    for i in "${!locations[@]}"; do
        if ((i != current_location)); then
            printf "  %d) %s\n" "$i" "${locations[i]}"
        fi
    done

    read -p "-> " dest
    if [[ $dest == "FLAVOURCOUNTRY" ]]; then
        echo "🚬🚬 Your cup runneth over."
        money=9999
        return
    fi

    if [[ $dest =~ ^[0-9]+$ ]] && ((dest < ${#locations[@]})) && ((dest != current_location)); then
        local travel_cost=50
        if ((money < travel_cost)); then
            echo "💸 You can't afford a ticket."
            return
        fi

        echo "🚇 Traveling to ${locations[dest]}..."
        money=$((money - travel_cost))
        current_location=$dest
        travels_today=$((travels_today + 1))
        travel_event
        travel_prices # Use the less volatile travel price adjustment
    else
        echo "❌ Invalid destination."
    fi
}

# Gameplay loop
new_prices

while ((days > 0)); do
    show_status
    echo "Actions: [B]uy, [S]ell, [T]ravel, [L]oan, Ban[K], [N]ext Day, [E]nd Game"
    read -r action
    echo

    case $action in
    b | B)
        buy_item
        ;;
    s | S)
        sell_item
        ;;
    t | T)
        travel
        ;;
    k | K)
        bank_menu
        ;;
    l | L)
        loan_menu
        ;;
    n | N)
        echo "💤 You head home for the night..."
        days=$((days - 1))
        if ((days <= 0)); then
            days=0 # Force game end
            continue
        fi
        travels_today=0
        debt=$(( debt + debt * interest / 100 ))
        newday_event
        new_prices
        ;;
    e | E)
        read -p "Are you sure you want to end the game? (y/n) " confirm
        if [[ $confirm == "y" || $confirm == "Y" ]]; then
            break
        fi
        ;;
    *)
        echo "❌ Invalid action."
        ;;
    esac
done

# Game over and score display
net_worth=$((money + bank))
final_score=$((net_worth - debt))

echo
echo "🏁 GAME OVER! 🏁"
echo "-------------------"
printf "Cash: \$%d\nBank: \$%d\nDebt: \$%d\n" "$money" "$bank" "$debt"
echo "-------------------"
printf "Final Net Worth: \$%d\n" "$final_score"

# Rank display
if ((final_score > 6000)); then
    echo "Ranking: 🕴️ Lvl.99 BOSS"
elif ((final_score > 3000)); then
    tmp=$((final_score - 3001))
    scale=$((6000 - 3001))
    level=$((50 + tmp * (89 - 50) / scale))
    echo "Ranking: 💎 Lvl.$level Capo"
elif ((final_score > 1000)); then
    tmp=$((final_score - 1001))
    scale=$((3000 - 1001))
    level=$((10 + tmp * (49 - 10) / scale))
    echo "Ranking: 🔪 Lvl.$level Gangster"
elif ((final_score > 0)); then
    echo "Ranking: 👶 Lvl.1 Thug"
else
    echo "🪦 You sleep with the fishes"
fi

# thank you for your attention
# bye~
