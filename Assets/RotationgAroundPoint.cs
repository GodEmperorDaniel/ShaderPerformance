using System.Collections;
using System.Collections.Generic;
using UnityEngine;
public class RotationgAroundPoint : MonoBehaviour
{
    [SerializeField]
    private Transform rotationPoint;
    [SerializeField]
    [Range(0f,10f)]
    private float rotationSpeed = 1;
    void Update()
    {
        transform.RotateAround(rotationPoint.position, Vector3.forward, rotationSpeed * 0.1f);
    }
}
