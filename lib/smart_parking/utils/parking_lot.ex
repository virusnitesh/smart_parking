defmodule SmartParking.Utils.ParkingLot do
  @moduledoc """
  A helper module for smart parking
  """

  alias ParkingLot.Utils.{Slot, Vehicle, Ticket}

  defstruct id: nil,
            slots: [],
            used_slots: []

  #######################     Public call functions      #####################

  def new(slot_count) do
    %__MODULE__{}
    |> add_id()
    |> add_slots(slot_count)
  end

  def park(parking_lot, registration_no, color) do
    with {:ok, slot} <- get_slot(parking_lot),
         %Vehicle{} = vehicle <- get_vehicle(registration_no, color),
         ticket <- create_ticket(slot, vehicle),
         new_slot <- add_ticket_to_slot(slot, ticket),
         parking_lot <- update_used_slot(new_slot, parking_lot, :insert),
         parking_lot <- update_slot_from_slots(slot, parking_lot, :delete) do
      {:ok, ticket, parking_lot}
    else
      {:error, message} ->
        {:error, message, parking_lot}

      _ ->
        {:error, "Some issue in parking", parking_lot}
    end
  end

  def leave(parking_lot, slot_id) do
    with [slot] <- fetch_slot(parking_lot, slot_id),
         parking_lot <- update_used_slot(slot, parking_lot, :delete),
         parking_lot <- update_slot_from_slots(slot, parking_lot, :insert),
         _update_ticket <- Ticket.update_ticket(slot) do
      {:ok, :success, parking_lot}
    else
      [] -> {:error, "Slot id invalid or slot already empty", parking_lot}
    end
  end

  #######################     Private functions      #####################

  defp add_id(%__MODULE__{} = parking_lot),
    do: %{parking_lot | id: generate_id()}

  defp generate_id, do: System.unique_integer([:monotonic, :positive])

  defp add_slots(%__MODULE__{} = parking_lot, slot_count) do
    slots =
      1..slot_count
      |> Stream.map(&Slot.new(id: &1))
      |> Enum.to_list()

    %{parking_lot | slots: slots}
  end

  defp get_slot(%__MODULE__{slots: [slot | _remaining_slots]}), do: {:ok, slot}
  defp get_slot(%__MODULE__{slots: []}), do: {:error, "Sorry, no parking lot available currently"}

  defp get_vehicle(registration_no, color),
    do: Vehicle.new(%{color: color, registration_no: registration_no})

  defp create_ticket(%Slot{id: id}, %Vehicle{} = vehicle) do
    %{slot_id: id, vehicle: vehicle}
    |> Ticket.new()
    |> Ticket.add_ticket()
  end

  defp add_ticket_to_slot(%Slot{} = slot, %Ticket{id: ticket_id}),
    do: %{slot | ticket_id: ticket_id}

  defp update_used_slot(slot, %__MODULE__{used_slots: used_slots} = parking_lot, :insert),
    do: %{parking_lot | used_slots: [slot | used_slots]}

  defp update_used_slot(slot, %__MODULE__{used_slots: used_slots} = parking_lot, :delete),
    do: %{parking_lot | used_slots: List.delete(used_slots, slot)}

  defp update_slot_from_slots(%Slot{id: id}, %__MODULE__{slots: slots} = parking_lot, :insert),
    do: %{parking_lot | slots: [Slot.new(id: id) | slots]}

  defp update_slot_from_slots(slot, %__MODULE__{slots: slots} = parking_lot, :delete),
    do: %{parking_lot | slots: List.delete(slots, slot)}

  defp fetch_slot(%__MODULE__{used_slots: used_slots}, slot_id),
    do: Enum.filter(used_slots, fn x -> x.id == slot_id end)
end
