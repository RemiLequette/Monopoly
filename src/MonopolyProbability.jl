module MonopolyProbability

export BOARD_SIZE, standard_board, standard_board_us

const BOARD_SIZE = 40

function standard_board()
    return [
        "Départ", "Boulevard de Belleville", "Caisse de communauté", "Rue Lecourbe", "Impôt sur le revenu",
        "Gare Montparnasse", "Rue de Vaugirard", "Chance", "Rue de Courcelles", "Avenue de la République",
        "Prison / Simple visite", "Boulevard de la Villette", "Compagnie d'électricité", "Avenue de Neuilly", "Rue de Paradis",
        "Gare de Lyon", "Avenue Mozart", "Caisse de communauté", "Boulevard Saint-Michel", "Place Pigalle",
        "Parc Gratuit", "Avenue Matignon", "Chance", "Boulevard Malesherbes", "Avenue Henri-Martin",
        "Gare du Nord", "Faubourg Saint-Honoré", "Place de la Bourse", "Compagnie des eaux", "Rue La Fayette",
        "Allez en prison", "Avenue de Breteuil", "Avenue Foch", "Caisse de communauté", "Boulevard des Capucines",
        "Gare Saint-Lazare", "Chance", "Avenue des Champs-Élysées", "Taxe de luxe", "Rue de la Paix"
    ]
end

function standard_board_us()
    return [
        "GO", "Mediterranean Avenue", "Community Chest", "Baltic Avenue", "Income Tax",
        "Reading Railroad", "Oriental Avenue", "Chance", "Vermont Avenue", "Connecticut Avenue",
        "Jail / Just Visiting", "St. Charles Place", "Electric Company", "States Avenue", "Virginia Avenue",
        "Pennsylvania Railroad", "St. James Place", "Community Chest", "Tennessee Avenue", "New York Avenue",
        "Free Parking", "Kentucky Avenue", "Chance", "Indiana Avenue", "Illinois Avenue",
        "B&O Railroad", "Atlantic Avenue", "Ventnor Avenue", "Water Works", "Marvin Gardens",
        "Go To Jail", "Pacific Avenue", "North Carolina Avenue", "Community Chest", "Pennsylvania Avenue",
        "Short Line", "Chance", "Park Place", "Luxury Tax", "Boardwalk"
    ]
end

end
