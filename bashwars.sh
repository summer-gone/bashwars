#!/bin/bash

echo " _______    ______    ______   __    __        __       __   ______   _______    ______  ";
echo "|       \\  /      \\  /      \\ |  \\  |  \\      |  \\  _  |  \\ /      \\ |       \\  /      \\ ";
echo "| \$\$\$\$\$\$\$\\|  \$\$\$\$\$\$\\|  \$\$\$\$\$\$\\| \$\$  | \$\$      | \$\$ / \\ | \$\$|  \$\$\$\$\$\$\\| \$\$\$\$\$\$\$\\|  \$\$\$\$\$\$\\";
echo "| \$\$__/ \$\$| \$\$__| \$\$| \$\$___\\\$\$| \$\$__| \$\$      | \$\$/  \$\\| \$\$| \$\$__| \$\$| \$\$__| \$\$| \$\$___\\\$\$";
echo "| \$\$    \$\$| \$\$    \$\$ \\\$\$    \\ | \$\$    \$\$      | \$\$  \$\$\$\\ \$\$| \$\$    \$\$| \$\$    \$\$ \\\$\$    \\ ";
echo "| \$\$\$\$\$\$\$\\| \$\$\$\$\$\$\$\$ _\\\$\$\$\$\$\$\\| \$\$\$\$\$\$\$\$      | \$\$ \$\$\\\$\$\\\$\$| \$\$\$\$\$\$\$\$| \$\$\$\$\$\$\$\\ _\\\$\$\$\$\$\$\\";
echo "| \$\$__/ \$\$| \$\$  | \$\$|  \\__| \$\$| \$\$  | \$\$      | \$\$\$\$  \\\$\$\$\$| \$\$  | \$\$| \$\$  | \$\$|  \\__| \$\$";
echo "| \$\$    \$\$| \$\$  | \$\$ \\\$\$    \$\$| \$\$  | \$\$      | \$\$\$    \\\$\$\$| \$\$  | \$\$| \$\$  | \$\$ \\\$\$    \$\$";
echo " \\\$\$\$\$\$\$\$  \\\$\$   \\\$\$  \\\$\$\$\$\$\$  \\\$\$   \\\$\$       \\\$\$      \\\$\$ \\\$\$   \\\$\$ \\\$\$   \\\$\$  \\\$\$\$\$\$\$ ";

# --- Game Setup ---
items=("Weed" "Ecstasy" "Meth" "Cocaine" "Heroin")

# Track current prices and market spikes
prices=(0 0 0 0 0)
spike_duration=(0 0 0 0 0)

# Player's inventory for each item
inventory=(0 0 0 0 0)

# Locations
locations=("Bronx" "Queens" "Brooklyn" "Manhattan" "Staten Island")
current_location=0

# Player stats
money=2000
debt=5000
bank=0
days=20
travels_today=0

# Define base prices and standard deviations for each item
base_price=(250 400 600 1000 1400)
std_dev=(70 90 110 130 150)

# --- Core Function ---
new_prices() {
  for i in "${!items[@]}"; do
    if (( spike_duration[$i] == 0 )); then
      mean=${base_price[i]}
      sd=${std_dev[i]}

      # Seed awk's random generator with current time + item index
      price=$(awk -v mean="$mean" -v sd="$sd" -v seed="$RANDOM" 'BEGIN {
        srand(seed)
        u1 = rand(); u2 = rand();
        z0 = sqrt(-2*log(u1)) * cos(2*3.14159*u2);
        p = int(mean + z0*sd);
        print p
      }')

      # Clamp the price to mean ± 3*sd
      (( price < mean - 3*sd )) && price=$(( mean - 3*sd ))
      (( price > mean + 3*sd )) && price=$(( mean + 3*sd ))
      (( price < 1 )) && price=1

      prices[$i]=$price
    fi
  done
}

newday_event() {
  local roll=$((RANDOM % 100))
  if (( roll < 5 )); then
    echo "🔫 You got hit at home! They took the whole stash!"
    for i in "${!inventory[@]}"; do
      inventory[$i]=0
    done
  elif (( roll < 15 )); then
    echo "🚨 Police raid! They found half your stash."
    for i in "${!inventory[@]}"; do
      inventory[$i]=$(( inventory[$i] / 2 ))
    done
  elif (( roll < 25 )); then
    if (( money > 500 )); then
      echo "💰 You got hit at home! They stole \$500!"
      money=$(( money - 500 ))
    else
      echo "💰 You got hit at home! They stole \$$money!"
      money=0
    fi
  elif (( roll < 40 )); then
    local idx=$(( RANDOM % ${#items[@]} ))
    # Only trigger a spike if one isn't already active for this item
    if (( spike_duration[$idx] == 0 )); then
      echo "🌝 A peaceful evening."
      random_message
      echo "📈 Prices for ${items[$idx]} skyrocket!"
      prices[$idx]=$(( prices[$idx] * 2 ))
      spike_duration[$idx]=$(( 2 + RANDOM % 2 )) # Spike for 2-3 days
    fi
  else
    echo "🌝 A peaceful evening."
  fi

  # Tick down the duration of any active market spikes
  for i in "${!spike_duration[@]}"; do
    if (( spike_duration[$i] > 0 )); then
      spike_duration[$i]=$(( spike_duration[$i] - 1 ))
      if (( spike_duration[$i] == 0 )); then
        echo "📉 The ${items[$i]} market stabilizes."
        new_prices   # regenerate normally instead of using old min/max arrays
      fi
    fi
  done
}

travel_event() {
  local roll=$((RANDOM % 100))

  if (( roll < 10 )); then
    echo "🔪 You were mugged! You lost \$200."
    money=$(( money - 200 ))
    (( money < 0 )) && money=0 # Ensure money doesn't go below zero
  elif (( roll < 15 )); then
    echo "🚨 Police raid! They found half your stash."
    for i in "${!inventory[@]}"; do
      inventory[$i]=$(( inventory[$i] / 2 ))
    done
  fi
}

# Displays the current game status
show_status() {
  echo
  echo "======================================================"
  echo "📍 Location: ${locations[$current_location]} | ✈️  Travels Left: $((2 - travels_today))"
  echo "📆 Day $((21-days))/20 — 💰 Cash: \$$money — 💸 Debt: \$$debt — 🏦 Bank: \$$bank"
  echo "------------------------------------------------------"
  echo "  #) Item       Price      Owned"
  echo "------------------------------------------------------"
  for i in "${!items[@]}"; do
    printf "  %d) %-10s \$%-9d %-5d\n" "$i" "${items[$i]}" "${prices[$i]}" "${inventory[$i]}"
  done
  echo "======================================================"
  echo
}

# Handles buying items
buy_item() {
  read -p "Buy which item number? " choice
  # Validate that the choice is a valid number and within the array bounds
  if ! [[ $choice =~ ^[0-9]+$ ]] || (( choice >= ${#items[@]} )); then
    echo "Invalid item number."
    return
  fi

  # Calculate and display how many the player can afford
  local price=${prices[$choice]}
  if (( price > 0 )); then
    local max_can_buy=$(( money / price ))
    echo "(You can afford $max_can_buy ${items[$choice]}.)"
  else
    echo "You can't afford it!"
    return
  fi

  read -p "How many? " amount
  # Validate that the amount is a positive number
  if ! [[ $amount =~ ^[0-9]+$ ]]; then
      echo "Invalid amount. Please enter a number."
      return
  fi
  # Don't allow buying zero
  if (( amount == 0 )); then
      return
  fi

  local cost=$(( prices[choice] * amount ))
  if (( cost <= money )); then
    money=$(( money - cost ))
    inventory[$choice]=$(( inventory[choice] + amount ))
    echo "Bought $amount ${items[choice]} for \$$cost."
  else
    echo "Not enough cash! You need \$$cost but only have \$$money."
  fi
}

sell_item() {
  read -p "Sell which item number? " choice
  if ! [[ $choice =~ ^[0-9]+$ ]] || (( choice >= ${#items[@]} )); then
    echo "Invalid item number."
    return
  fi

  read -p "How many? " amount
  if ! [[ $amount =~ ^[1-9][0-9]*$ ]]; then
    echo "Invalid amount. Enter a positive number."
    return
  fi

  # Force integer interpretation in case of leading zeros
  amount=$((10#$amount))

  if (( amount <= inventory[choice] )); then
    local earnings=$(( prices[choice] * amount ))
    money=$(( money + earnings ))
    inventory[$choice]=$(( inventory[choice] - amount ))
    echo "Sold $amount ${items[choice]} for \$$earnings."
  else
    echo "You don't have that many to sell!"
  fi
}

# Handles banking and loan payments
bank_menu() {
  echo "[D]eposit, [W]ithdraw, [P]ay loan, or [X] to cancel?"
  read -r action
  echo
  local amt=0

  case $action in
    d|D)
      read -p "Deposit amount: " amt
      # Validate input
      if [[ $amt =~ ^[1-9][0-9]*$ ]] && (( amt <= money )); then
        money=$((money-amt))
        bank=$((bank+amt))
        echo "Deposited \$$amt."
      else
        echo "Invalid amount or not enough cash."
      fi
      ;;
    w|W)
      read -p "Withdraw amount: " amt
      # Validate input
      if [[ $amt =~ ^[1-9][0-9]*$ ]] && (( amt <= bank )); then
        bank=$((bank-amt))
        money=$((money+amt))
        echo "Withdrew \$$amt."
      else
        echo "Invalid amount or not enough in the bank."
      fi
      ;;
    p|P)
      read -p "Pay how much on your loan? " amt
      # Validate input
      if [[ $amt =~ ^[1-9][0-9]*$ ]] && (( amt <= money )); then
        money=$((money-amt))
        debt=$((debt-amt))
        (( debt < 0 )) && debt=0
        echo "Paid \$$amt towards your debt."
      else
        echo "Invalid amount or not enough cash."
      fi
      ;;
    x|X)
      return
      ;;
    *)
      echo "Invalid option."
      ;;
  esac
}

# Handles traveling to a new location
travel() {
  # Check if the player has any travels left for the day
  if (( travels_today >= 2 )); then
    echo "😴 You're too tired to travel again today."
    return
  fi

  echo "Where to? (Tickets \$50)"
  for i in "${!locations[@]}"; do
    if (( i != current_location )); then
      echo "  $i) ${locations[$i]}"
    fi
  done

read -p "Choice: " dest
if [[ $dest =~ ^[0-9]+$ ]] && (( dest < ${#locations[@]} )); then
    if (( dest == current_location )); then
        echo "You're already here! (${locations[$dest]})"
        return
    fi

    # Normal travel code
    local travel_cost=50
    echo "Traveling to ${locations[$dest]}..."
    if (( money < travel_cost )); then
        echo "You can't afford to travel!"
        return
    fi
    money=$(( money - travel_cost ))
    current_location=$dest
    travels_today=$(( travels_today + 1 )) # Use one travel charge
    travel_event
    new_prices
else
    echo "Invalid destination."
fi
}

messages=(
    "👮 Border Patrol seizes a huge shipment..."
    "🔥 Warehouse fire burns through stock..."
    "👽 Feds intercept a major delivery..."
    "⚔️ Gang war affects supply..."
    "🫨 Panic causes supply run..."
)

random_message() {
    local index=$(( RANDOM % ${#messages[@]} ))
    echo "${messages[$index]}"
}

# Function to check if player is completely broke
broke() {
  # Check money and bank first
  if (( money == 0 && bank == 0 )); then
    # Now check inventory
    for item in "${inventory[@]}"; do
      if (( item != 0 )); then
        return 1  # Not completely broke
      fi
    done
    return 0  # All checks passed: completely broke
  else
    return 1  # money or bank not zero
  fi
}

# -------- MAIN GAME LOOP -------- #
new_prices # Generate initial prices for the first day
while (( days > 0 )); do
  if broke; then
    echo "😭 You're broke!"
    days=0
    break
  fi
  show_status
  echo "Actions: [B]uy, [S]ell, [T]ravel, Ban[k], [N]ext Day, [Q]uit"
  read -r action
  echo

  case $action in
    b|B) buy_item ;;
    s|S) sell_item ;;
    t|T) travel ;;
    k|K) bank_menu ;;
    n|N)
      echo "💤 You go home for the day..."
      days=$((days-1))
      travels_today=0 # Reset travel counter
      debt=$((debt + debt/10)) # 10% interest accrues
      newday_event
      new_prices # Recalculate prices for the new day
      ;;
    q|Q)
      echo "Are you sure you want to quit? (y/n)"
      read -r confirm
      echo
      if [[ $confirm == "y" || $confirm == "Y" ]]; then
        break
      fi
      ;;
    *)
      echo "Invalid action."
      ;;
  esac
done

# -------- GAME END -------- #
net_worth=$(( money + bank ))
final_score=$(( net_worth - debt ))
echo
echo "🏁 GAME OVER! 🏁"
echo "-------------------"
echo "Final Cash:   \$$money"
echo "Bank Balance: \$$bank"
echo "Remaining Debt: \$$debt"
echo "-------------------"
echo "Final Net Worth: \$$final_score"
echo

if (( final_score > 6000 )); then
  echo "Your Rank: Level 99 BOSS"
elif (( final_score > 3000 )); then
  echo "Your Rank: Level 60 Capo"
elif (( final_score > 0 )); then
  echo "Your Rank: Level 35 Gangster"
else
  echo "Your Rank: Level 1 Thug"
fi
