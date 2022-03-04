//
//  WeatherTableViewController.swift
//  StaticWeatherApp
//
//  Created by Johnny Pesavento on 2/15/22.
//

import UIKit
import Foundation
import SystemConfiguration

class weatherCell: UITableViewCell {
    
    @IBOutlet weak var weatherImage: UIImageView!
    @IBOutlet weak var weatherLabel: UILabel!
    @IBOutlet weak var weatherDescription: UILabel!
    
}

class Reachability {

    class func isConnectedToNetwork() -> Bool {

        var zeroAddress = sockaddr_in(sin_len: 0, sin_family: 0, sin_port: 0, sin_addr: in_addr(s_addr: 0), sin_zero: (0, 0, 0, 0, 0, 0, 0, 0))
        zeroAddress.sin_len = UInt8(MemoryLayout.size(ofValue: zeroAddress))
        zeroAddress.sin_family = sa_family_t(AF_INET)

        let defaultRouteReachability = withUnsafePointer(to: &zeroAddress) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {zeroSockAddress in
                SCNetworkReachabilityCreateWithAddress(nil, zeroSockAddress)
            }
        }

        var flags: SCNetworkReachabilityFlags = SCNetworkReachabilityFlags(rawValue: 0)
        if SCNetworkReachabilityGetFlags(defaultRouteReachability!, &flags) == false {
            return false
        }

        /* Only Working for WIFI
        let isReachable = flags == .reachable
        let needsConnection = flags == .connectionRequired

        return isReachable && !needsConnection
        */

        // Working for Cellular and WIFI
        let isReachable = (flags.rawValue & UInt32(kSCNetworkFlagsReachable)) != 0
        let needsConnection = (flags.rawValue & UInt32(kSCNetworkFlagsConnectionRequired)) != 0
        let ret = (isReachable && !needsConnection)

        return ret

    }
}

class WeatherTableViewController: UITableViewController {
    
    struct CityItem {
        var name = ""
        var coordinates = ""
        var description = ""
        var longDescription = ""
        var picture = UIImage(named: "Sunny")
    }
    
    var cities: [CityItem] = [
        CityItem(name: "Durham", coordinates: "63,65"),
        CityItem(name: "Chapel Hill", coordinates: "58,61"),
        CityItem(name: "Carrboro", coordinates: "57,60"),
        CityItem(name: "Morrisville", coordinates: "67,58"),
        CityItem(name: "Raleigh", coordinates: "73,56"),
        CityItem(name: "Cary", coordinates: "68,56"),
    ]
    
    // MARK: - Welcome
    struct CityResult: Codable {
        let context: [ContextElement]
        let type: String
        let geometry: Geometry
        let properties: Properties

        enum CodingKeys: String, CodingKey {
            case context = "@context"
            case type, geometry, properties
        }
    }

    enum ContextElement: Codable {
        case contextClass(ContextClass)
        case string(String)

        init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            if let x = try? container.decode(String.self) {
                self = .string(x)
                return
            }
            if let x = try? container.decode(ContextClass.self) {
                self = .contextClass(x)
                return
            }
            throw DecodingError.typeMismatch(ContextElement.self, DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Wrong type for ContextElement"))
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.singleValueContainer()
            switch self {
            case .contextClass(let x):
                try container.encode(x)
            case .string(let x):
                try container.encode(x)
            }
        }
    }

    // MARK: - ContextClass
    struct ContextClass: Codable {
        let version: String
        let wx: String
        let geo, unit: String
        let vocab: String

        enum CodingKeys: String, CodingKey {
            case version = "@version"
            case wx, geo, unit
            case vocab = "@vocab"
        }
    }

    // MARK: - Geometry
    struct Geometry: Codable {
        let type: String
    }

    // MARK: - Properties
    struct Properties: Codable {
        let units, forecastGenerator: String
        let validTimes: String
        let elevation: Elevation
        let periods: [Period]
    }

    // MARK: - Elevation
    struct Elevation: Codable {
        let unitCode: String
    }

    // MARK: - Period
    struct Period: Codable {
        let number: Int
        let name: String
        let isDaytime: Bool
        let temperature: Int
        let temperatureUnit: TemperatureUnit
        let windSpeed, windDirection: String
        let icon: String
        let shortForecast, detailedForecast: String
    }

    enum TemperatureUnit: String, Codable {
        case f = "F"
    }

    override func viewDidLoad() {
        if Reachability.isConnectedToNetwork() {
            for i in 0...cities.count-1 {
                self.getAllData(idx: i)
            }
        } else {
            let dialogMessage = UIAlertController(title: "Warning", message: "You are currently offline. Please connect to the internet to get weather data.", preferredStyle: .alert)
            
            //Add OK button to a dialog message
            dialogMessage.addAction(UIAlertAction(title: "OK", style: .default))
            // Present Alert to
            self.present(dialogMessage, animated: true, completion: nil)
        }
    }

    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return cities.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "forecastCell", for: indexPath) as! weatherCell

        cell.weatherImage.image = cities[indexPath.row].picture
        cell.weatherLabel.text = cities[indexPath.row].name
        cell.weatherDescription.text = cities[indexPath.row].description
        return cell
    }
    
    func getAllData(idx: Int) {
            
            let mySession = URLSession(configuration: URLSessionConfiguration.default)
        
            let url = URL(string: String(format: "https://api.weather.gov/gridpoints/RAH/%@/forecast", self.cities[idx].coordinates))!
        
            print(url)
        
            let task = mySession.dataTask(with: url) { data, response, error in
            // ensure there is no error for this HTTP response
            guard error == nil else {
                print ("Error: \(error!)") // local console message for debug

                 DispatchQueue.main.async {
                    let alert = UIAlertController(title: "Error - ", message: "\(error!)", preferredStyle: .alert)
                    alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
                    self.present(alert, animated: true)
                }
                 
                return
            }
            
            // check response code
            
            // ensure there is data returned from this HTTP response
            guard let jsonData = data else {
                print("No data")
                return
            }
            
            do {
                let decoded = try JSONDecoder().decode(CityResult.self, from: jsonData)

                let url = URL(string: decoded.properties.periods[0].icon.dropLast(6) + "large")
                let data = try? Data(contentsOf: url!) //make sure your image in this url does exist, otherwise unwrap in a if let check / try-catch
                self.cities[idx].picture = UIImage(data: data!)
                
                self.cities[idx].description = String(format: "%@, %d°", decoded.properties.periods[0].shortForecast, decoded.properties.periods[0].temperature)
                
                self.cities[idx].longDescription = decoded.properties.periods[0].detailedForecast
                
                print(decoded.properties.periods[0])
                DispatchQueue.main.async {
                    self.tableView.reloadData()
                }
                
            } catch {
                DispatchQueue.main.async {
                   let alert = UIAlertController(title: "JSON Decode Error - ", message: "\(error)", preferredStyle: .alert)
                   alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
                   self.present(alert, animated: true)
               }
            }
        }
        
        task.resume()
        
    }


    /*
    // Override to support conditional editing of the table view.
    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        // Return false if you do not want the specified item to be editable.
        return true
    }
    */

    /*
    // Override to support editing the table view.
    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            // Delete the row from the data source
            tableView.deleteRows(at: [indexPath], with: .fade)
        } else if editingStyle == .insert {
            // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
        }    
    }
    */

    /*
    // Override to support rearranging the table view.
    override func tableView(_ tableView: UITableView, moveRowAt fromIndexPath: IndexPath, to: IndexPath) {

    }
    */

    /*
    // Override to support conditional rearranging of the table view.
    override func tableView(_ tableView: UITableView, canMoveRowAt indexPath: IndexPath) -> Bool {
        // Return false if you do not want the item to be re-orderable.
        return true
    }
    */

    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
        
        let destVC = segue.destination as! detailViewController
        let selectRow = tableView.indexPathForSelectedRow?.row
        
        destVC.localLabelText = cities[selectRow!].name
        destVC.localDescriptionText = cities[selectRow!].longDescription
        destVC.localImage = cities[selectRow!].picture
        
    }

}
