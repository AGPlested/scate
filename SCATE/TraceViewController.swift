//
//  TraceViewController.swift
//  ISCAT
//
//  Created by Andrew on 30/07/2016.
//  Copyright © 2016 Andrew Plested. All rights reserved.
//

import UIKit
import SwiftyDropbox
// when you get an error about compilation under wrong Swift version, use:
// carthage update --platform iOS in the directory to retrieve and rebuild


class TraceViewController: UIViewController, UIScrollViewDelegate, UITableViewDataSource, UITableViewDelegate, FitViewControllerDelegate, SettingsViewControllerDelegate, EventsViewControllerDelegate {

    @IBOutlet weak var eventsFitsStack: UIStackView!
    @IBOutlet weak var sv: UIScrollView!
    @IBOutlet weak var zoomButton: UIButton!
    @IBOutlet weak var zoomLabel: UILabel!
    @IBOutlet weak var progressLabel: UILabel!
    @IBOutlet weak var statusLabel: UILabel!

    @IBOutlet weak var rawDataFilenameLabel: UILabel!
    @IBOutlet weak var dataFileHelper: UILabel!
    
    @IBOutlet weak var recentFitsTable: UITableView!
    @IBOutlet weak var recentFitsView: UIView!
    
    @IBOutlet weak var quickSettingsView: UIView!

    var recentFitsTableRows = [recentEventTableItem]()
    
    let v = TraceDisplay() //content view
    var s = SettingsList()
    let ld = TraceIO()     //file retrieval
    let compView = completionView()
    
    var masterEventList = eventList()
    
    //for recent fits info panel
    var recentFitList = [eventList]()
    
    var pointIndex : Int = 0
    var traceLength : Int?
    var traceArray = [Int16]() //  this array will hold the trace data
    
    
    let tStart = 0
    var xp : CGFloat = 0    //the xposn of the trace
    
    var originalContentSize = CGSize()
    var progress = Float()
    var offset = CGPoint() //view offset
    var viewSize = CGRect()
    
    //store the text labels so that their size can be adjusted with zoom
    var labelsOnXAxis = [UILabel]()
    
    var originalZoom = CGFloat(1)
    let eventCellReuseID = "recentFitCell"
    
    func updateLabels () {
        zoomLabel.text = String(format:"%.1f", sv.zoomScale)
        progress = 100 * Float(sv.contentOffset.x) / Float(sv.contentSize.width)
        if (progress < 0) {
            progress = 0
        }
        progressLabel.text = String(format:"%.1f%%", progress)
        rawDataFilenameLabel.text = String(s.dataFilename.getStringValue())
        dataFileHelper.text = String(s.rawDataFileType.getStringValue())
        
    }

    
    func traceView(arr: [Int16]) {
        //sv.backgroundColor = UIColor.darkGray
        sv.translatesAutoresizingMaskIntoConstraints = false
        sv.minimumZoomScale = 0.1
        sv.maximumZoomScale = 10
        
        if sv != nil {
            sv.delegate = self
        }
        
        sv.addSubview(v)        //UIView
        
        //v.compression is the fraction of the data points plotted
        //its inverse is the stride through the array of all points
        
        let dataFileLength = arr.count
        let headerSize = s.header.getIntValue()
        traceLength = dataFileLength - headerSize
        let scaledTraceLength = Int (v.compression * CGFloat(traceLength!))
        
        let calInScreenPts = Int (Float(v.compression) * Float(s.sampleRate.getFloatValue()) / 100) //calibration of 10 ms
        
        let nCalibrators = Int (scaledTraceLength / calInScreenPts) //same whatever the compression
        
        var xC = 0
        
        for i in 0..<nCalibrators {
        
            //calibrator label
            let lab = UILabel()
            labelsOnXAxis.append(lab)   //store references for easy adjustment later
            lab.text = "\(i * 10)"      //each calibrator is 10 ms
            lab.textColor = UIColor.lightGray
            lab.font = lab.font.withSize(14.0 / sv.zoomScale)
            lab.sizeToFit()
            lab.frame.origin = CGPoint(x:xC+5, y:105)  //offset
            
            //x scale bar
            let scale = xRuler()
            let scaleLayer = scale.axisLayer(widthInScreenPoints: CGFloat(calInScreenPts), minorT: 5)
            scaleLayer.frame.origin = CGPoint(x:xC, y:100)
            
            scaleLayer.strokeColor = UIColor.lightGray.cgColor
            scaleLayer.lineJoin = kCALineJoinRound
            scaleLayer.fillColor = nil
            scaleLayer.lineWidth = 0.5
            
            v.addSubview(lab)
            v.layer.addSublayer(scaleLayer)
            xC += calInScreenPts
        }
        
        let chunk = Int (Float(calInScreenPts) / Float(v.compression))
        let chunkN = Int (traceLength! / chunk )        // the number of data chunks to display
        
        let step = ceil(1 / Double(v.compression))
        
        print ("step, cN, cN*ch, tL, sTL:",step, chunkN, chunkN * chunk, traceLength!, scaledTraceLength)
        
        print ("Drawing trace from \(s.dataFilename.getStringValue())")
        
        var firstPoint = CGPoint(x:xp, y:200)           //xp is the x position
        var drawnPoint = CGPoint(x:xp, y:200)
        
        for i in 0..<chunkN {
            
            //drawing trace
            let thickness: CGFloat = 1.5
            let tracePath = UIBezierPath()
            tracePath.move(to: firstPoint)
            
            for index in stride(from:0, to: chunk, by: Int(step))  {
                pointIndex = index + headerSize + tStart + i * chunk
                
                //xp is separately scaled by tDrawScale
                drawnPoint = CGPoint(x: xp + v.compression * CGFloat(index), y: CGFloat(200) * (1.0 + CGFloat(arr[pointIndex]) / 32536.0))
                tracePath.addLine(to: drawnPoint)
            }
            
            //grab the last plotted point for next iteration
            firstPoint = drawnPoint
            //print (i, firstPoint)
            
            // render to layer
            let traceLayer = CAShapeLayer()
            traceLayer.path = tracePath.cgPath
            //pinkish orange trace
            traceLayer.strokeColor = UIColor(red: 0.946, green: 0.9, blue: 0.548, alpha: 1.0).cgColor
            traceLayer.lineJoin = kCALineJoinRound
            traceLayer.fillColor = nil
            traceLayer.lineWidth = thickness
            v.layer.addSublayer(traceLayer)             //accumulate a bunch of anonymous layers.
            
            xp += CGFloat(chunk) * v.compression
        }
        
        var sz = sv.bounds.size     //Not sure what these three lines do any more.
        sz.width = xp
        sv.contentSize = sz     //change size to

    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        
        //Load the trace
        traceArray = ld.loadData(dataFilename : s.dataFilename.getStringValue())
        //print (trace[0])
        traceView(arr: traceArray)
        sv.addSubview(compView)
        sv.bouncesZoom = false
        statusLabel.text = "No fit yet"
        updateLabels()
        
        /*
        if masterEventList.count() != 0 {
            compView.updateSegments(eventL: masterEventList, y: 150, samplePerMs: Float (v.tDrawScale) * Float (s.sampleRate.getFloatValue()) / 1000.0)
        }
        //samplePerMs here is a misnomer - it's actually samples drawn on the screen per ms
        */
        recentFitsTable.dataSource = self
        recentFitsTable.delegate = self
        
        //recent fits table is first supplied with a dummy, in order to print no fit yet (-1).
        let recentFitsCellContents = recentEventTableItem(eL: eventList(), position: -1)
        recentFitsTableRows.append (recentFitsCellContents)

        // Do any additional setup after loading the view, typically from a nib.
    }

    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    // MARK: - Table view data source
    
    func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return recentFitsTableRows.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let rCell: RecentFitCell = tableView.dequeueReusableCell(withIdentifier: eventCellReuseID, for: indexPath) as! RecentFitCell
        
        let item = recentFitsTableRows[indexPath.row]
        rCell.orderLabel.text =  item.rank
        rCell.infoLabel.text =  item.info
        rCell.eventsLabel.text =  item.events
        return rCell
    }

    
    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        return v
        
    }
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        //print ("scrolled", sv.contentOffset)
        updateLabels()
        sv.isUserInteractionEnabled = true
    }
    
    func scrollViewDidEndZooming(_ scrollView: UIScrollView, with view: UIView?, atScale scale: CGFloat) {

        var sz = sv.bounds.size
        sz.width = xp * scale
        sz.height *= scale  //reset size of view
        sv.contentSize = sz
        
        //modulate axis ticklabels by zoomScale when view gets tiny
        for axisLabel in labelsOnXAxis {
            let tickFontSize = max ((14.0 / sv.zoomScale), 14.0)
            axisLabel.font = axisLabel.font.withSize(tickFontSize)
            axisLabel.sizeToFit() //no clipping please
        }
        
        updateLabels()
        //compView.contentScaleFactor = scale not the right answer!
        
        print ("content size after resize", sv.contentSize.width, "offset after resize" , sv.contentOffset.x)
        sv.isUserInteractionEnabled = true
    }
    
    
    func scrollViewWillBeginZooming(_ scrollView: UIScrollView, with view: UIView?) {
   
        self.offset = sv.contentOffset
        self.originalZoom = sv.zoomScale //needed to keep the view centred
        self.originalContentSize = sv.contentSize
        
        print ("begin zoom", self.offset, self.originalZoom)
    }
    
    func scrollViewDidZoom(_ scrollView: UIScrollView) {
        //print("scrollViewDidZoom")
        
        let zoomFactor = (sv.zoomScale / self.originalZoom)   // relative to original zoom during transition
        //sv.contentOffset = CGPoint(x:self.offset.x * zoomFactor + sv.bounds.width / 2 * (zoomFactor - 1), y:self.offset.y * zoomFactor + sv.bounds.height / 2 * (zoomFactor - 1))
        
        //affine transform was updated on view to make only x-zooming
        sv.contentOffset = CGPoint(x:self.offset.x * zoomFactor + sv.bounds.width / 2 * (zoomFactor - 1), y:sv.contentOffset.y)
        //update progress counter but with special values
        
        //to get the progress meter correct, the
        //original content size must be scaled by the zoom factor during the zoom
        
        progress = 100 * Float(sv.contentOffset.x) / Float(self.originalContentSize.width * zoomFactor)
        updateLabels()
        
    }

    //mark actions
    
    func EventsVCDidFinish(controller: EventsViewController, updatedEvents: eventList) {
        print ("Events returned", updatedEvents)
        masterEventList = updatedEvents
        controller.dismiss(animated: true, completion: {})
    }
    
    func FitVCDidFinish(controller: FittingViewController, leftEdge: Float, fit:eventList) {
        print ("left edge \(leftEdge) ms")
        print ("Fit", fit)
        
        //recentFitList is initialized empty
        //skip updating after empty or rejected fits
        if !fit.list.isEmpty {
            recentFitList.append(fit)
        
            //wash out the recent fits table data source and repopulate, latest first...
            //need to do append and re-iterate in this crude way rather than simple insert
            //because place should update for table
            
            recentFitsTableRows = []
            var place = recentFitList.count
            for eventList in recentFitList.reversed() {
                let recentFitsCellContents = recentEventTableItem(eL: eventList, position: place)
                recentFitsTableRows.append (recentFitsCellContents)
                place -= 1
                //not a beautiful way to do it, but reversed().enumerated() doesn't fly??
            }
            recentFitsTable.reloadData()
        }
        
        
        //reject fit button returns an empty list
        
        
        
        guard fit.count() > 0 else {
            statusLabel.text = String(format:"No fit or fit rejected. Nothing stored ")
            controller.dismiss(animated: true, completion: {})
            return
        }
        
        //by doing it this way, lose timestamps and event order
        //need a helper function to append list to list
        //look at creation time of list to get overall order of old and new events
        //for example....
        
        for event in fit.list {
            masterEventList.eventAppend(e: event)
        }
        
        if masterEventList.count() != 0 {
            compView.updateSegments(eventL: masterEventList, y: 200, samplePerMs: Float(v.compression) * Float(s.sampleRate.getFloatValue()) / 1000.0 )
        }
            
        // now provide much simplified status report because info is in "Recent fits" table
        statusLabel.text = String(format:"Stored fit: %@",fit.titleGenerator())
        controller.dismiss(animated: true, completion: {})
    }
    
    func SettingsVCDidFinish(controller: SettingsViewController, updatedS: SettingsList) {
        print ("Settings updated", updatedS)
        s = updatedS
        controller.dismiss(animated: true, completion: {})
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "FitViewSegue"
        {
            print ("FitViewSegue triggered.")
            if let destinationVC = segue.destination as? FittingViewController {
                let samplesPerMillisecond = s.sampleRate.getFloatValue() / 1000.0
                
                destinationVC.progressCounter = self.progress
                //progress excludes the header
                
                destinationVC.settings = s
                let dataLength = Float(traceLength!) // not scaled
                
                // in ms
                destinationVC.leftEdgeTime = (dataLength / Float(samplesPerMillisecond)) * (self.progress / 100 )  //progress is percentage
                
                //need to check for plausible header value here
                //work in real not compressed data space
                let leftPoint = s.header.getIntValue() + Int(self.progress / 100 * dataLength)
                let rightPoint = leftPoint + Int(dataLength * Float(sv.bounds.width / sv.contentSize.width))
                print (leftPoint, rightPoint, rightPoint-leftPoint, traceArray.count, sv.bounds.width, sv.contentSize.width) //these points are a bit off??
                
                let fitSlice = Array(self.traceArray[leftPoint..<rightPoint])
                //print (fitSlice.count, sv.bounds.width / sv.contentSize.width, dataLength * Float(sv.bounds.width / sv.contentSize.width) )
                destinationVC.pointsToFit = fitSlice
                destinationVC.delegate = self
            }
        }
        else if segue.identifier == "SettingsViewSegue"
            {
            print ("SettingsViewSegue triggered.")
            if let destinationVC = segue.destination as? SettingsViewController {
                
                //preparation for segue to settings goes here
                //reference to settings object is passed and returned
                destinationVC.localSettings = s
                destinationVC.delegate = self
            }
        }
        else if segue.identifier == "EventsViewSegue"
            //must set this in segue!!!
            {
            print ("EventsViewSegue triggered.")
            if let destinationVC = segue.destination as? EventsViewController {
                    
                //preparation for segue to settings goes here
                //reference to event object is passed and returned
                destinationVC.localEventsList = masterEventList
                destinationVC.delegate = self
                
            }
        }
    }
    
    
    //add vertical zoom?

    
    //if this code executes, trace display disappears but otherwise app still runs
    @IBAction func zoomIn(_ sender: UIButton) {
    
        //need to put a defensive limit in here to avoid overshoot
        self.offset = sv.contentOffset
        print ("hard zooming", self.offset)
        v.compression *= 2       //increase the horizontal zoom factor
        v.layer.sublayers = nil //kill all the existing layers (ALL!!!)
        
        
         //add display of zoom factor
        
        //redraw the view
        traceView(arr: traceArray)
        
        print ("redrawn", sv.contentOffset)
        sv.contentOffset = CGPoint (x: self.offset.x * v.compression, y: self.offset.y)
    }

    //if this code executes, trace display disappears but otherwise app still runs
    
    @IBAction func zoomOut(_ sender: UIButton) {
        //need to put a defensive limit in here to avoid undershoot (data disappears!)
        
        v.compression /= 2           //reduce the horizontal zoom factor
        v.layer.sublayers = nil     //kill all the existing layes (ALL!!!)
        
        //add display of zoom factor
        
        //redraw the view
        traceView(arr: traceArray)
    }
  


}

